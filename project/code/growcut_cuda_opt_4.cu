
#include <limits.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <fstream>

#include "assert.h"
#include "dataset.h"
#include "mfi.h"
#include "timer.h"

#include "math.h"
#include "cuda.h"
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

using namespace std;

#define RADIUS 1
#define MAX_ITERATIONS 2048 / 32
#define BLOCKDIM_X 8
#define BLOCKDIM_Y 8

template <typename T0, typename T1> static T0 zCeil(const T0 &n, const T1 &d) {
  return (T0) ceil(static_cast<double>(n) / static_cast<double>(d));
}

#define cudaCheck(stmt) _cudaCheck(__LINE__, stmt)
#define _cudaCheck(line, stmt)                                                 \
  do {                                                                         \
    cudaError_t p_err = stmt;                                                  \
    assert(p_err == cudaSuccess);                                              \
    if (p_err != cudaSuccess) {                                                \
      printf("ERROR on line %d (%s): %s -- %d\n", line, #stmt,                 \
             cudaGetErrorString(p_err), p_err);                                \
    }                                                                          \
  } while (0)

#define _max(x, y) (((x) > (y)) ? x : y)
#define _min(x, y) (((x) < (y)) ? x : y)
#define g(x, y) (1 - _max(x, y) - _min(x, y) / 2)

__global__ void growcut(unsigned short const *__restrict__ img, char *label,
                        float *strength, int height, int width) {

  __shared__ unsigned short
      imgShared[BLOCKDIM_Y + 2 * RADIUS][BLOCKDIM_X + 2 * RADIUS];
  __shared__ char lShared[BLOCKDIM_Y + 2 * RADIUS][BLOCKDIM_X + 2 * RADIUS];
  __shared__ float sShared[BLOCKDIM_Y + 2 * RADIUS][BLOCKDIM_X + 2 * RADIUS];
  __shared__ char ltShared[BLOCKDIM_Y][BLOCKDIM_X];
  __shared__ float stShared[BLOCKDIM_Y][BLOCKDIM_X];

  int tidX = threadIdx.x;
  int tidY = threadIdx.y;
  int tx = tidX;
  int ty = tidY;
  int jj = tidX + BLOCKDIM_X * blockIdx.x;
  int ii = tidY + BLOCKDIM_Y * blockIdx.y;

#define idx(arry, y, x)                                                        \
  ((y) >= 0 && (y) < height && (x) >= 0 && (x) < width)                        \
      ? arry[(y) * width + (x)]                                                \
      : 0

  tidY += RADIUS;
  tidX += RADIUS;

  imgShared[tidY][tidX] = idx(img, ii, jj);
  sShared[tidY][tidX] = idx(strength, ii, jj);
  lShared[tidY][tidX] = idx(label, ii, jj);

  if (tx < RADIUS) {
    imgShared[tidY][tidX - RADIUS] = idx(img, ii, jj - RADIUS);
    sShared[tidY][tidX - RADIUS] = idx(strength, ii, jj - RADIUS);
    lShared[tidY][tidX - RADIUS] = idx(label, ii, jj - RADIUS);

    imgShared[tidY][tidX + BLOCKDIM_X] = idx(img, ii, jj + BLOCKDIM_X);
    sShared[tidY][tidX + BLOCKDIM_X] = idx(strength, ii, jj + BLOCKDIM_X);
    lShared[tidY][tidX + BLOCKDIM_X] = idx(label, ii, jj + BLOCKDIM_X);
  }

  if (ty < RADIUS) {
    imgShared[tidY - RADIUS][tidX] = idx(img, ii - RADIUS, jj);
    sShared[tidY - RADIUS][tidX] = idx(strength, ii - RADIUS, jj);
    lShared[tidY - RADIUS][tidX] = idx(label, ii - RADIUS, jj);

    imgShared[tidY + BLOCKDIM_Y][tidX] = idx(img, ii + BLOCKDIM_Y, jj);
    sShared[tidY + BLOCKDIM_Y][tidX] = idx(strength, ii + BLOCKDIM_Y, jj);
    lShared[tidY + BLOCKDIM_Y][tidX] = idx(label, ii + BLOCKDIM_Y, jj);
  }

  for (int kk = 0; kk < 16; kk++) {
    __syncthreads();
    char nl = 0;
    float ns = 0;
    if (jj < width && ii < height) {
      char lq;
      float sq, gc;
      unsigned short cq;

      unsigned short cp = imgShared[tidY][tidX];
      char lp = lShared[tidY][tidX];
      float sp = sShared[tidY][tidX];
      nl = lp;
      ns = sp;

      cq = imgShared[tidY - 1][tidX];
      lq = lShared[tidY - 1][tidX];
      sq = sShared[tidY - 1][tidX];
      gc = g(cp, cq) * sq;
      if (gc > sp) {
        nl = lq;
        ns = gc;
      }

      cq = imgShared[tidY + 1][tidX];
      lq = lShared[tidY + 1][tidX];
      sq = sShared[tidY + 1][tidX];
      gc = g(cp, cq) * sq;
      if (gc > sp) {
        nl = lq;
        ns = gc;
      }

      cq = imgShared[tidY][tidX - 1];
      lq = lShared[tidY][tidX - 1];
      sq = sShared[tidY][tidX - 1];
      gc = g(cp, cq) * sq;
      if (gc > sp) {
        nl = lq;
        ns = gc;
      }

      cq = imgShared[tidY][tidX + 1];
      lq = lShared[tidY][tidX + 1];
      sq = sShared[tidY][tidX + 1];
      gc = g(cp, cq) * sq;
      if (gc > sp) {
        nl = lq;
        ns = gc;
      }

    }

    ltShared[ty][tx] = nl;
    stShared[ty][tx] = ns;

    __syncthreads();

    lShared[tidY][tidX] = ltShared[ty][tx];
    sShared[tidY][tidX] = stShared[ty][tx];

    if (tx < RADIUS) {
      sShared[tidY][tidX - RADIUS] =
          (sShared[tidY][tidX - RADIUS] + stShared[ty][tx]) / 2;
      lShared[tidY][tidX - RADIUS] =
          (lShared[tidY][tidX - RADIUS] + ltShared[ty][tx]) / 2;

      sShared[tidY][tidX + BLOCKDIM_X] =
          (sShared[tidY][tidX + BLOCKDIM_X] +
           stShared[ty][BLOCKDIM_X - tx - RADIUS]) / 2;
      lShared[tidY][tidX + BLOCKDIM_X] =
          (lShared[tidY][tidX + BLOCKDIM_X] +
           ltShared[ty][BLOCKDIM_X - tx - RADIUS]) / 2;
    }

    if (ty < RADIUS) {
      sShared[tidY - RADIUS][tidX] =
          (sShared[tidY - RADIUS][tidX] + stShared[ty][tx]) / 2;
      lShared[tidY - RADIUS][tidX] =
          (lShared[tidY - RADIUS][tidX] + ltShared[ty][tx]) / 2;

      sShared[tidY + BLOCKDIM_Y][tidX] =
          (sShared[tidY + BLOCKDIM_Y][tidX] +
           stShared[BLOCKDIM_Y - ty - RADIUS][tx]) / 2;
      lShared[tidY + BLOCKDIM_Y][tidX] =
          (lShared[tidY + BLOCKDIM_Y][tidX] +
           ltShared[BLOCKDIM_Y - ty - RADIUS][tx]) / 2;
    }

  }
  if (jj < width && ii < height) {
    label[ii * width + jj] = ltShared[ty][tx];
    strength[ii * width + jj] = stShared[ty][tx];
  }
  return;
}

int runGrowCut(MFI *mfi, char *label, int *iterations0) {
  int iterations = 0;
  int width = mfi->width;
  int height = mfi->height;
  char *nextLabel = (char *)malloc(sizeof(char) * width * height);
  float *strength = (float *)malloc(sizeof(float) * width * height);
  float *nextStrength = (float *)malloc(sizeof(float) * width * height);
  unsigned short *cap_source = (unsigned short *)mfi->cap_source;
  unsigned short *cap_sink = (unsigned short *)mfi->cap_sink;
  int len = width * height;
  for (int ii = 0; ii < len; ii++) {
    float s = label[ii] != 0;
    strength[ii] = s;
  }

  unsigned short *dcapsource;
  float *dStrength;
  char *dLabel;

  cudaCheck(cudaMalloc(&dcapsource, sizeof(unsigned short) * len));
  cudaCheck(cudaMalloc(&dStrength, sizeof(float) * len));
  cudaCheck(cudaMalloc(&dLabel, sizeof(char) * len));

  cudaCheck(cudaMemcpy(dcapsource, mfi->cap_source,
                       sizeof(unsigned short) * len, cudaMemcpyHostToDevice));
  cudaCheck(
      cudaMemcpy(dLabel, label, sizeof(char) * len, cudaMemcpyHostToDevice));
  cudaCheck(cudaMemcpy(dStrength, strength, sizeof(float) * len,
                       cudaMemcpyHostToDevice));

  dim3 blockDim(BLOCKDIM_X, BLOCKDIM_Y);
  dim3 gridDim(zCeil(width, blockDim.x), zCeil(height, blockDim.x));

  while (iterations++ < MAX_ITERATIONS) {
    growcut << <gridDim, blockDim>>>
        (dcapsource, dLabel, dStrength, height, width);
    cudaCheck(cudaThreadSynchronize());
  }

  cudaCheck(
      cudaMemcpy(label, dLabel, sizeof(char) * len, cudaMemcpyDeviceToHost));

  cudaFree(dcapsource);
  cudaFree(dStrength);
  cudaFree(dLabel);

  free(nextLabel);
  free(strength);
  free(nextStrength);

  *iterations0 = iterations;
  return -1;
}

int main(int argc, char **argv) {

  const char *dataset_path =
      argc == 2 ? argv[1] : "C:\\Users\\abduld\\Documents\\visual studio "
                            "2012\\Projects\\growcut\\x64\\Debug\\dataset";

  int num_instances = (sizeof(instances) / sizeof(Instance));

  ofstream timesFile;
  string timeFileName = string(dataset_path);
  timeFileName.append("\\..\\times_cuda_opt_c2070_alpha_max_itermore.data");
  timesFile.open(timeFileName, ios::out);
  timesFile << "instance,num,width,height,changes,iterations,time\n";

  for (int i = 0; i < num_instances; i++) {

    for (int j = 0; j < instances[i].count; j++) {
      char fileName[1024];

      ofstream myfile;
      string sfileName;
      int iterations;
      unsigned short *cap_source;
      unsigned short *cap_sink;
      char *label;
      int changes;
      uint64_t tic, toc;
      double compute_time;

      sprintf(fileName, instances[i].filename, dataset_path, j);
      MFI *mfi = mfi_read(fileName);

      if (!mfi) {
        //printf("FAILED to read instance %s\n",fileName);
        goto skip;
      }

      if (mfi->connectivity != 4 || mfi->dimension != 2 ||
          mfi->type_terminal_cap != MFI::TYPE_UINT16 ||
          mfi->type_neighbor_cap != MFI::TYPE_UINT16) {
        goto skip;
      }

      cap_source = (unsigned short *)mfi->cap_source;
      cap_sink = (unsigned short *)mfi->cap_sink;
      label = (char *)calloc(mfi->width * mfi->height, sizeof(char));
      for (int ii = 0; ii < mfi->width * mfi->height; ii++) {
        if (cap_source[ii] > 15000) {
          label[ii] = 1;
        }
        if (cap_sink[ii] > 15000) {
          label[ii] = -1;
        }
      }

      tic = _hrtime();
      changes = runGrowCut(mfi, label, &iterations);
      toc = _hrtime();

      compute_time = (toc - tic) / 1000000000.0f;

      sfileName = string(fileName);
      sfileName.append(".dat");

      myfile.open(sfileName, ios::out);

      for (int ii = 0; ii < mfi->height; ii++) {
        for (int jj = 0; jj < mfi->width; jj++) {
          myfile << ((int) label[ii * mfi->width + jj] + 2) / 2 << " ";
          //myfile << ((int) cap_sink[ii*mfi->width + jj]) << " ";
        }
        myfile << "\n";
      }
      myfile.close();

      printf("%s,%d,%d,%d,%d,%d,%0.9f \n", instances[i].name, j, mfi->width,
             mfi->height, changes, iterations, compute_time);
      timesFile << instances[i].name << "," << j << "," << mfi->width << ","
                << mfi->height << "," << changes << "," << iterations << ","
                << compute_time << "\n";
      timesFile.flush();
      free(label);
    skip:
      if (mfi != NULL)
        mfi_free(mfi);

    }
  }
  timesFile.close();
  return 0;
}
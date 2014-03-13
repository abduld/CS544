
> My research area is compilers and architecture. 
> Attempts were made to apply optimization to my area, but they were 
> abandoned since they were quite a bit involved for a homework project.
> It is my hope to use optimization for instruction selection (in the compiler)
> for my class project.

In this report we will examine the differences of Quasi-Newton's method and Polak Ribiere using 2 criterions.
<!-- 3 criteria.
The first criteria is algorithmic ---  we will look at
 the algorithm and derive the $O(n)$ complexity as long
    as some insights as to wether the algorithm is parallizable.
The second would -->
    We will then look at how efficient it is at finding the solution.
To facilitate this, we will be finding the minimum for a function of two variables.
The final criteria is how well it performs in practice for a sample application.
We will use Poisson blending of two images here.

<!--------

## Algorithmic Exploration

Given a function $f : $

### Quasi-Newton's Method


### Polak Ribiere

----------------------------->

## Exploration in 2D

We start by exploring the two methods using functions of 2 arguments.
The figure bellow shows the results.
As can be observed, Newton's method takes more steps but evaluates the function
    a few times less.
Polak Ribier take less steps and evaluates the equation more times.

\begin{figure}[t!]
\includegraphics[scale=0.16, angle=90]{exp.png}
\caption{Experimentation between Quasi-Newton and Polak Ribiere. The first column shows the function to be minimized, the second show the Quasi-Newton results, and the third show the results from Polak Ribiere.}
\label{fig:exp}
\centering
\end{figure}

Figuring out which one to choose in this case would be dependent on how complicated the function is.
If evaluation of the function would take a long time, then PR would be used and Newton would be used otherwise.

## Poisson Blending

To evaluate the methods using thousands of variables, we will use posson blending (as said previously it took quite a bit of time to find an application outside my field that was still interesting : other applications examined were neural networks, image segementation using mean shift, and genetic algorithms).

Given two images source $S$ and target $T$ with an acomaning mast $M$.
The Poisson blending method performs a cut and paste image operation from
    $S$ to $T$ minimizing the variation at the boundary.
Mathematically, we want to minimize the variation within the mask within
    the contraint that the boundary values must come from the target image.
    
$$
\underset{f}{\text{min}} \iint\limits_\Omega \lvert* \del f \rvert*^6 \text{ with } f* \lvert_{\partial \Omega} = f \lvert_{\partial \Omega}
$$

This is a least squares minimization problem that can be solved
    by constructing the equation $Ax = b$ and solving for $x$.
Where $x$ is an $N \times N$ vector corresponding to the output pixels,
    and $A$ is an $(N \times N) \times (N \times N)$ matrix corresponding
    to the constraints, and $b$ corresponds to the known values.
The matrix $A$ is constructed by

    for ii from 0 to N:
        for jj from 0 to N:
            A[idx(ii, jj), idx(ii, jj)] = -4
            B[idx(ii, jj)] = 4*S[ii, jj] - S[ii + 1, jj + 1] -
                               S[ii + 1, jj - 1] - S[ii - 1, jj + 1] +
                               S[ii - 1, jj - 1]
            for (x,y) in [(1, 1), (-1, -1), (1, -1), (-1, 1)] :
                if M[ii + x, jj + y] == 0
                    A[idx(ii, jj), idx(ii + x, jj + y)] = -1
                else
                    B[idx(ii + y, jj + x)] -= T[ii + x,jj + y]

with `idx` being an auxilary function defined by

    idx(ii, jj) := ii*(N*N) + jj

It is clear that $A$ is a very sparse matrix with at most $4$ entries in each row.
We now evaluate solving for $x$ using both Quasi-Newton and Polak Ribiere based least squares solver.
We will varry the number of unknown by resizing the input images.

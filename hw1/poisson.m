

constructMatricies[source_, target_, mask_] :=
	Module[{A, b, w, h, lsource, maskBoundary, btmp, fltIdx},
		lsource = LaplacianFilter[source, 1];
		{w, h} = ImageDimensions[source];
		fltIdx[x_, y_] := y * w + x;
		maskBoundary = Thinning[EdgeDetect[mask, 2, Method -> "ShenCastan"]];
		b = {}; (* {1 -> 0, {w*h}->0}; *)
		A = Reap[
			(*
			Sow[{1, 1} -> 0];
			Sow[{fltIdx[0, h], fltIdx[0, h]} -> 0];
			*)
			Do[
				If[PixelValue[mask, {ii,jj}] == 1,
					Sow[{fltIdx[ii, jj], fltIdx[ii, jj]} -> -4];
					btmp = PixelValue[lsource, {ii, jj}];
					Do[
						If[PixelValue[mask, {ii + xOffset, jj + yOffset}] == 1,
							Sow[{fltIdx[ii + xOffset, jj + yOffset], fltIdx[ii + xOffset, jj + yOffset]} -> -1],
							btmp += PixelValue[target, {ii + xOffset, jj + yOffset}]
						],
						{xOffset, {-1, 1}},
						{yOffset, {-1, 1}}
					];
					AppendTo[b, fltIdx[ii, jj] -> btmp];
				]
				, {ii, w}
				, {jj, h}
			]
		][[2, 1]];
		SparseArray /@ {A, b}
	]


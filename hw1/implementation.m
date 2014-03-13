

Internal`SetVisualizationOptions[MeshRegions2D -> False]

ClearAll[oFindMinimum]
SetAttributes[oFindMinimum, {HoldAll}];
oFindMinimum[f_, vars_List, start_List, opts:OptionsPattern[]] :=
	Module[{rs, sol, pts, evalCount = 0, stepCount = 0},
		rs = Reap[
			FindMinimum[Unevaluated[f],
								  MapThread[List, {vars, start}],
								  opts,
								  StepMonitor :> (stepCount++; Sow[vars]),
								  EvaluationMonitor :> (evalCount++;)
			]
		];

		sol = First[rs];
		pts = rs[[2, 1]];

		MinimumInformation[
			<|
				"Function" -> Unevaluated[f],
				"Variables" -> vars,
				"Start" -> start,
				"Points" -> PrependTo[pts, start],
				"Solution" -> sol,
				"EvaluationCount" -> evalCount,
				"StepCount" -> stepCount
			|>
		]
	]

ClearAll[MinimumInformation]
MinimumInformation[as_Association]["Range"] :=
		MapIndexed[
			{#1, Min[as["Points"][[All, #2]]] - 1, Max[as["Points"][[All, #2]]] + 1}&,
			as["Variables"]
		]

MinimumInformation[as_Association]["Plot"] :=
	Module[{range},
		range = Sequence@@(MinimumInformation[as]["Range"]);
		With[{rng = range, f = as["Function"]},
			Show[
				ContourPlot[
					f,
					rng,
					PlotTheme -> "Detailed"
				],
				Graphics[{
						Black,
						Line[as["Points"]],
						Red,
						Point[as["Points"]],
						PointSize[0.03],
						Point[as["Solution"][[2, All, 2]]]
				}]
			]
		]
	]

MinimumInformation[as_Association]["Plot3D"] :=
	Module[{range, ev},
		range = Sequence@@(MinimumInformation[as]["Range"]);
		With[{rng = range, f = as["Function"]},
			ev = Table[
				AppendTo[pt, 0.1 + f /. (MapThread[Rule, {as["Variables"], pt}])],
				{pt, as["Points"]}
			];
			Show[
				Plot3D[f, rng, PlotTheme -> "Detailed"],
				Graphics3D[{
					Black,
					Thick,
					Line[ev],
					Red,
					PointSize[0.03],
					Point[ev],
					Point[
						Append[
							as["Solution"][[2, All, 2]],
							as["Solution"][[1]]
						]
					]
				}]
			]
		]
	]

MinimumInformation[as_Association][v_] /; KeyExistsQ[as, v] :=
	as[v]


ClearAll[CompareMethods]
SetAttributes[CompareMethods, {HoldAll}];
CompareMethods[f_, vars_, start_] :=
	Module[{qn, pr},
		qn = oFindMinimum[f, vars, start, Method -> {"QuasiNewton", "StepMemory" -> 10}];
		pr = oFindMinimum[f, vars, start, Method -> {"ConjugateGradient", Method -> "PolakRibiere"}];
		{
			TraditionalForm[First@f],
			Labeled[
				GraphicsRow[{qn["Plot"]}, ImageSize -> Scaled[0.3]],
				StringJoin[{
					"Function Evaluation Count = ",
					ToString[qn["EvaluationCount"]],
					", Iteration Count = ",
					ToString[qn["StepCount"]]
				}]
			],
			Labeled[
				GraphicsRow[{pr["Plot"]}, ImageSize -> Scaled[0.3]],
				StringJoin[{
					"Function Evaluation Count = ",
					ToString[pr["EvaluationCount"]],
					", Iteration Count = ",
					ToString[pr["StepCount"]]
				}]
			]
		}
	]


Internal`SetVisualizationOptions[MeshRegions2D -> False]

ClearAll[oFindMinimum]
SetAttributes[oFindMinimum, {HoldAll}];
oFindMinimum[f_, vars_, start_, opts:OptionsPattern[]] :=
	Module[{rs, sol, pts, time, arg, evalCount = 0, stepCount = 0},
		arg = If[start === None,
			vars,
			MapThread[List, {vars, start}]
		];
		rs = Reap[
			AbsoluteTiming[
				FindMinimum[Unevaluated[f],
							arg,
							opts,
							StepMonitor :> (stepCount++; Sow[vars]),
							EvaluationMonitor :> (evalCount++;)
				]
			]
		];

		{time, sol} = First[rs];
		pts = rs[[2, 1]];
		If[start != None,
			PrependTo[pts, start]
		];

		MinimumInformation[
			<|
				"EvaluationTime" -> time,
				"Function" -> Unevaluated[f],
				"Variables" -> vars,
				"Start" -> start,
				"Points" -> pts,
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
CompareMethods[f_, vars_, start_:None, showGraphicsQ_:True] :=
	Module[{qn, pr, prtext, qntext},
		qn = oFindMinimum[f, vars, start, Method -> {"QuasiNewton", "StepMemory" -> Infinity}];
		pr = oFindMinimum[f, vars, start, Method -> {"ConjugateGradient", Method -> "PolakRibiere"}];
		prtext = StringJoin[{
					"Evaluation Time = ",
					ToString[pr["EvaluationTime"]],
					"\nFunction Evaluation Count = ",
					ToString[pr["EvaluationCount"]],
					"\nIteration Count = ",
					ToString[pr["StepCount"]]
				}];
		qntext = StringJoin[{
					"Evaluation Time = ",
					ToString[qn["EvaluationTime"]],
					"\nFunction Evaluation Count = ",
					ToString[qn["EvaluationCount"]],
					"\nIteration Count = ",
					ToString[qn["StepCount"]]
				}];
		If[showGraphicsQ === True && start =!= None,
			{
				TraditionalForm[First@f],
				Labeled[
					GraphicsRow[{qn["Plot"]}, ImageSize -> Scaled[0.3]],
					qntext
				],
				Labeled[
					GraphicsRow[{pr["Plot"]}, ImageSize -> Scaled[0.3]],
					prtext
				]
			},
			<|
				"VariableCount" -> Length[vars],
				"QuasiNewton" -> <|
					"EvaluationTime" -> qn["EvaluationTime"],
					"EvaluationCount" -> qn["EvaluationCount"],
					"StepCount" -> qn["StepCount"]
				|>,
				"PolakRibiere" -> <|
					"EvaluationTime" -> pr["EvaluationTime"],
					"EvaluationCount" -> pr["EvaluationCount"],
					"StepCount" -> pr["StepCount"]
				|>
			|>
		]
	]
(proclaim '(optimize (speed 3) (safety 0) (debug 0) (compilation-speed 0)))
(push :ecs-unsafe *features*)
(ql:quickload '(#:ecs-tutorial-1 #:deploy))
(asdf:make :ecs-tutorial-1)

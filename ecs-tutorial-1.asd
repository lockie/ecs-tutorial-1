(defsystem "ecs-tutorial-1"
  :version "0.0.1"
  :author "Andrew Kravchuk"
  :license "MIT"
  :depends-on (#:alexandria
               #:cl-fast-ecs
               #:cl-liballegro
               #:cl-liballegro-nuklear
               #:livesupport)
  :serial t
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "main"))))
  :description "cl-fast-ecs framework tutorial."
  :defsystem-depends-on (#:deploy)
  :build-operation "deploy-op"
  :build-pathname #P"ecs-tutorial-1"
  :entry-point "ecs-tutorial-1:main")

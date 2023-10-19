(in-package #:ecs-tutorial-1)

(define-constant +window-width+ 800)
(define-constant +window-height+ 600)

(define-constant +repl-update-interval+ 0.3d0)

(define-constant +font-path+ "../Resources/inconsolata.ttf"
  :test #'string=)
(define-constant +font-size+ 24)

(define-constant +config-path+ "../config.cfg"
  :test #'string=)

(ecs:define-component position
  "Determines the location of the object, in pixels."
  (x 0.0 :type single-float :documentation "X coordinate")
  (y 0.0 :type single-float :documentation "Y coordinate"))

(ecs:define-component speed
  "Determines the speed of the object, in pixels/second."
  (x 0.0 :type single-float :documentation "X coordinate")
  (y 0.0 :type single-float :documentation "Y coordinate"))

(ecs:define-component acceleration
  "Determines the acceleration of the object, in pixels/second^2."
  (x 0.0 :type single-float :documentation "X coordinate")
  (y 0.0 :type single-float :documentation "Y coordinate"))

(ecs:define-component image
  "Stores ALLEGRO_BITMAP structure pointer, size and scaling information."
  (bitmap (cffi:null-pointer) :type cffi:foreign-pointer)
  (width 0.0 :type single-float)
  (height 0.0 :type single-float)
  (scale 1.0 :type single-float))

(ecs:define-component planet
  "Tag component to indicate that entity is a planet.")

(declaim
 (type single-float
       *planet-x* *planet-y* *planet-width* *planet-height* *planet-mass*))
(defvar *planet-x*)
(defvar *planet-y*)
(defvar *planet-width*)
(defvar *planet-height*)
(defvar *planet-mass* 500000.0)

(ecs:define-system draw-images
  (:components-ro (position image)
   :initially (al:hold-bitmap-drawing t)
   :finally (al:hold-bitmap-drawing nil))
  (let ((scaled-width (* image-scale image-width))
        (scaled-height (* image-scale image-height)))
    (al:draw-scaled-bitmap image-bitmap 0 0
                           image-width image-height
                           (- position-x (* 0.5 scaled-width))
                           (- position-y (* 0.5 scaled-height))
                           scaled-width scaled-height 0)))

(ecs:define-system move
  (:components-ro (speed)
   :components-rw (position)
   :arguments ((:dt single-float)))
  (incf position-x (* dt speed-x))
  (incf position-y (* dt speed-y)))

(ecs:define-system accelerate
  (:components-ro (acceleration)
   :components-rw (speed)
   :arguments ((:dt single-float)))
  (incf speed-x (* dt acceleration-x))
  (incf speed-y (* dt acceleration-y)))

(ecs:define-system pull
  (:components-ro (position)
   :components-rw (acceleration))
  (let* ((distance-x (- *planet-x* position-x))
         (distance-y (- *planet-y* position-y))
         (angle (atan distance-y distance-x))
         (distance-squared (+ (expt distance-x 2) (expt distance-y 2)))
         (acceleration (/ *planet-mass* distance-squared)))
    (setf acceleration-x (* acceleration (cos angle))
          acceleration-y (* acceleration (sin angle)))))

(ecs:define-system crash-asteroids
  (:components-ro (position)
   :components-no (planet)
   :with ((planet-half-width planet-half-height)
          :of-type (single-float single-float)
          := (values (/ *planet-width* 2.0)
                     (/ *planet-height* 2.0))))
  (when (<= (+ (expt (/ (- position-x *planet-x*) planet-half-width) 2)
               (expt (/ (- position-y *planet-y*) planet-half-height) 2))
            1.0)
    (ecs:delete-entity entity)))

(define-constant asteroid-images
    '("../Resources/a10000.png" "../Resources/a10001.png"
      "../Resources/a10002.png" "../Resources/a10003.png"
      "../Resources/a10004.png" "../Resources/a10005.png"
      "../Resources/a10006.png" "../Resources/a10007.png"
      "../Resources/a10008.png" "../Resources/a10009.png"
      "../Resources/a10010.png" "../Resources/a10011.png"
      "../Resources/a10012.png" "../Resources/a10013.png"
      "../Resources/a10014.png" "../Resources/a10015.png"
      "../Resources/b10000.png" "../Resources/b10001.png"
      "../Resources/b10002.png" "../Resources/b10003.png"
      "../Resources/b10004.png" "../Resources/b10005.png"
      "../Resources/b10006.png" "../Resources/b10007.png"
      "../Resources/b10008.png" "../Resources/b10009.png"
      "../Resources/b10010.png" "../Resources/b10011.png"
      "../Resources/b10012.png" "../Resources/b10013.png"
      "../Resources/b10014.png" "../Resources/b10015.png")
  :test #'equalp)

(defun init ()
  (ecs:bind-storage)
  (let ((background-bitmap-1 (al:ensure-loaded
                              #'al:load-bitmap
                              "../Resources/parallax-space-stars.png"))
        (background-bitmap-2 (al:ensure-loaded
                              #'al:load-bitmap
                              "../Resources/parallax-space-far-planets.png")))
    (ecs:make-object
     `((:position :x 400.0 :y 200.0)
       (:image :bitmap ,background-bitmap-1
               :width ,(float (al:get-bitmap-width background-bitmap-1))
               :height ,(float (al:get-bitmap-height background-bitmap-1)))))
    (ecs:make-object
     `((:position :x 100.0 :y 100.0)
       (:image :bitmap ,background-bitmap-2
               :width ,(float (al:get-bitmap-width background-bitmap-2))
               :height ,(float (al:get-bitmap-height background-bitmap-2))))))
  (let ((planet-bitmap (al:ensure-loaded
                        #'al:load-bitmap
                        "../Resources/parallax-space-big-planet.png")))
    (setf *planet-width* (float (al:get-bitmap-width planet-bitmap))
          *planet-height* (float (al:get-bitmap-height planet-bitmap))
          *planet-x* (/ +window-width+ 2.0)
          *planet-y* (/ +window-height+ 2.0))
    (ecs:make-object `((:planet)
                       (:position :x ,*planet-x* :y ,*planet-y*)
                       (:image :bitmap ,planet-bitmap
                               :width ,*planet-width*
                               :height ,*planet-height*))))
  (let ((asteroid-bitmaps
          (map 'list
               #'(lambda (filename)
                   (al:ensure-loaded #'al:load-bitmap filename))
               asteroid-images)))
    (dotimes (_ 5000)
      (let ((r (random 20.0))
            (angle (float (random (* 2 pi)) 0.0)))
        (ecs:make-object `((:position :x ,(+ 200.0 (* r (cos angle)))
                                      :y ,(+ *planet-y* (* r (sin angle))))
                           (:speed :x ,(+ -5.0 (random 15.0))
                                   :y ,(+ 30.0 (random 30.0)))
                           (:acceleration)
                           (:image
                            :bitmap ,(alexandria:random-elt asteroid-bitmaps)
                            :scale ,(+ 0.1 (random 0.9))
                            :width 64.0 :height 64.0)))))))

(declaim (type fixnum *fps*))
(defvar *fps* 0)

(defun update (dt)
  (unless (zerop dt)
    (setf *fps* (round 1 dt)))
  (ecs:run-systems :dt (float dt 0.0)))

(defvar *font*)

(defun render ()
  (al:draw-text *font* (al:map-rgba 255 255 255 0) 0 0 0
                (format nil "~d FPS" *fps*)))

(cffi:defcallback %main :int ((argc :int) (argv :pointer))
  (declare (ignore argc argv))
  (handler-bind
      ((error #'(lambda (e) (unless *debugger-hook*
                         (al:show-native-message-box
                          (cffi:null-pointer) "Hey guys"
                          "We got a big error here :("
                          (with-output-to-string (s)
                            (uiop:print-condition-backtrace e :stream s))
                          (cffi:null-pointer) :error)))))
    (al:set-app-name "ecs-tutorial-1")
    (let ((config (al:load-config-file +config-path+)))
      (unless (cffi:null-pointer-p config)
        (al:merge-config-into (al:get-system-config) config)))
    (unless (al:init)
      (error "Initializing liballegro failed"))
    (unless (al:init-primitives-addon)
      (error "Initializing primitives addon failed"))
    (unless (al:init-image-addon)
      (error "Initializing image addon failed"))
    (unless (al:init-font-addon)
      (error "Initializing liballegro font addon failed"))
    (unless (al:init-ttf-addon)
      (error "Initializing liballegro TTF addon failed"))
    (unless (al:install-audio)
      (error "Intializing audio addon failed"))
    (unless (al:init-acodec-addon)
      (error "Initializing audio codec addon failed"))
    (unless (al:restore-default-mixer)
      (error "Initializing default audio mixer failed"))
    (let ((display (al:create-display +window-width+ +window-height+))
          (event-queue (al:create-event-queue)))
      (when (cffi:null-pointer-p display)
        (error "Initializing display failed"))
      (al:inhibit-screensaver t)
      (al:set-window-title display "ECS Tutorial 1")
      (al:register-event-source event-queue
                                (al:get-display-event-source display))
      (al:install-keyboard)
      (al:register-event-source event-queue
                                (al:get-keyboard-event-source))
      (al:install-mouse)
      (al:register-event-source event-queue
                                (al:get-mouse-event-source))
      (unwind-protect
           (cffi:with-foreign-object (event '(:union al:event))
             (init)
             (livesupport:setup-lisp-repl)
             (loop
               :named main-game-loop
               :with *font* := (al:ensure-loaded #'al:load-ttf-font
                                                 +font-path+
                                                 (- +font-size+) 0)
               :with ticks :of-type double-float := (al:get-time)
               :with last-repl-update :of-type double-float := ticks
               :with dt :of-type double-float := 0d0
               :while (loop
                        :named event-loop
                        :while (al:get-next-event event-queue event)
                        :for type := (cffi:foreign-slot-value
                                      event '(:union al:event) 'al::type)
                        :always (not (eq type :display-close)))
               :do (let ((new-ticks (al:get-time)))
                     (setf dt (- new-ticks ticks)
                           ticks new-ticks))
                   (when (> (- ticks last-repl-update)
                            +repl-update-interval+)
                     (livesupport:update-repl-link)
                     (setf last-repl-update ticks))
                   (al:clear-to-color (al:map-rgb 0 0 0))
                   (livesupport:continuable
                     (update dt)
                     (render))
                   (al:flip-display)
               :finally (al:destroy-font *font*)))
        (al:inhibit-screensaver nil)
        (al:destroy-event-queue event-queue)
        (al:destroy-display display)
        (al:stop-samples)
        (al:uninstall-system)
        (al:uninstall-audio)
        (al:shutdown-ttf-addon)
        (al:shutdown-font-addon)
        (al:shutdown-image-addon))))
  0)

(defun main ()
  (float-features:with-float-traps-masked
      (:divide-by-zero :invalid :inexact :overflow :underflow)
    (al:run-main 0 (cffi:null-pointer) (cffi:callback %main))))


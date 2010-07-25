# function pipeline

An attempt at creating a "function pipeline" for managing game object animation, to see if it can be used as an alternative to the standard bloated "fat controller" animation handler used in many game engines.

Rather than using the controller to check if animations are complete or not, we have a function pointer pipeline that is cleared on each cycle of the game loop.  The pipeline does not need to know anything about the functions on the pipeline -- it simply makes the assumption that each function pointer on the pipeline has a good reason to be there.  Each function is pulled off the pipeline and executed in the order added.  If the related task is not yet complete, the function can add itself to the pipeline again.

TODO: Figure out a way to added closures to the pipeline to reduce the amount of bookkeeping code.
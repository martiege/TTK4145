# Mutex and Channel basics

### What is an atomic operation?
> An atomic operation is an operation on shared memory, which can be completed in a single step relative to any other threads. Therefore, no other thread can interact with it while it hasn't been completed.

### What is a semaphore?
> A semaphore is a variable which is used to control access to shared memory by multiple threads.

### What is a mutex?
> A mutex is something which only allows one thread at a time to access it.

### What is the difference between a mutex and a binary semaphore?
> The main difference is that only the thread that locked a mutex is supposed to unlock it.

### What is a critical section?
> The shared memory between the threads. 

### What is the difference between race conditions and data races?
 > A data race is where to instructions from different threads access the same shared memory, at least one tries to write and there is no synchronization, while a race condition is a problem in the timing which leads to problems. 

### List some advantages of using message passing over lock-based synchronization primitives.
> Easier to log, send smaller amount of data, communicate between different computers.

### List some advantages of using lock-based synchronization primitives over message passing.
> Can be faster, easier to implement

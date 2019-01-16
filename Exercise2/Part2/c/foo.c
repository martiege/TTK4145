#include <pthread.h>
#include <stdio.h>

int i = 0;
pthread_mutex_t mutex;

// Note the return type: void*
void* incrementingThreadFunction(){
    for (int j = 0; j < 1000000 + 1; j++) {
	    // TODO: sync access to i
        pthread_mutex_lock(&mutex);
	    
        i++;

        pthread_mutex_unlock(&mutex);
    }

    return NULL;
}

void* decrementingThreadFunction(){
    for (int j = 0; j < 1000000; j++) {
	    // TODO: sync access to i
        pthread_mutex_lock(&mutex);

	    i--;

        pthread_mutex_unlock(&mutex);
    }

    return NULL;
}


int main(){
    pthread_t incrementingThread, decrementingThread;

    pthread_mutex_init(&mutex, NULL);
    
    pthread_create(&incrementingThread, NULL, incrementingThreadFunction, NULL);
    pthread_create(&decrementingThread, NULL, decrementingThreadFunction, NULL);
    
    pthread_join(incrementingThread, NULL);
    pthread_join(decrementingThread, NULL);

    pthread_mutex_destroy(&mutex);
    
    printf("The magic number is: %d\n", i);
    return 0;
}

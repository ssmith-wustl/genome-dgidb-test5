#include <stdio.h>
#include <stdlib.h>
#include <malloc.h>
#include <string.h>

int main ()
{
    FILE *file = fopen("/tmp/tempout", "a+");
    
    char string[1000000];
    memset(string,0x01, 1000000);
    string[999999]=0x00;
    int i = 0;
    for(i=0;i<2048;i++)
    {
        fputs(string, file);
    }
    
    fclose(file);


}

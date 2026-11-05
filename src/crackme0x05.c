#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void parell(char* password) {
    int result;

    sscanf(password, "%d", &result);
    if ((result & 1) == 0) {
        printf("Password OK!\n");
        exit(0);
    }
}

void check(char* password) {
    int value;
    int sum;
    int i;
    char current;

    sum = 0;
    for (i = 0; i < strlen(password); ++i) {
        current = password[i];
        sscanf(&current, "%d", &value);
        sum += value;

        if (sum == 16)
            parell(password);
    }

    printf("Password Incorrect!\n");
}

int main() {
    char password[120];

    printf("IOLI Crackme Level 0x05\n");
    printf("Password: ");
    scanf("%s", password);

    check(password);

    return 0;
}

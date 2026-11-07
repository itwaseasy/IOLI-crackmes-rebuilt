#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void check(const char* password) {
    // sscanf() reads past current; in this order, the next byte is i's, as
    // in the original.
    int sum;
    int i;
    char current;
    int value;

    sum = 0;
    for (i = 0; i < strlen(password); ++i) {
        current = password[i];
        sscanf(&current, "%d", &value);
        sum += value;

        if (sum == 15) {
            printf("Password OK!\n");
            exit(0);
        }
    }

    printf("Password Incorrect!\n");
}

int main() {
    char password[120];

    printf("IOLI Crackme Level 0x04\n");
    printf("Password: ");
    scanf("%s", password);

    check(password);

    return 0;
}

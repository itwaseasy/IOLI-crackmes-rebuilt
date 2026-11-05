#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int LOL = 0;

int dummy(int value, char** envp) {
    int i = 0;

    while (envp[i] != NULL) {
        if (strncmp(envp[i++], "LOLO", 3) == 0) {
            LOL = 1;
            return 1;
        }
    }

    return 0;
}

void che() {
    printf("Password Incorrect!\n");
    exit(0);
}

void parell(char* password, char** envp) {
    int result;
    int i;

    sscanf(password, "%d", &result);

    if (dummy(result, envp) != 0) {
        for (i = 0; i <= 9; ++i) {
            if ((result & 1) == 0) {
                if (LOL == 1) 
                    printf("Password OK!\n");
                exit(0);
            }
        }
    }
}

void check(char* password, char** envp) {
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
            parell(password, envp);
    }

    che();

    // Unreachable (che() exits), but present in the original.
    if (dummy(value, envp) != 0) {
        for (i = 0; i <= 9; ++i) {
            if ((value & 1) == 0) {
                printf("wtf?\n");
                exit(0);
            }
        }
    }
}

int main(int argc, char** argv, char** envp) {
    char password[120];

    printf("IOLI Crackme Level 0x07\n");
    printf("Password: ");
    scanf("%s", password);

    check(password, envp);

    return 0;
}

#include <stdio.h>
#include <string.h>

int main() {
    char password[24];

    printf("IOLI Crackme Level 0x00\n");
    printf("Password: ");

    scanf("%s", password);
    if (strcmp(password, "250382") != 0)
        printf("Invalid Password!\n");
    else
        printf("Password OK :)\n");

    return 0;
}

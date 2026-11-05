#include <stdio.h>

int main() {
    int password;

    printf("IOLI Crackme Level 0x01\n");
    printf("Password: ");

    scanf("%d", &password);
    if (password != 5274)
        printf("Invalid Password!\n");
    else
        printf("Password OK :)\n");

    return 0;
}

#include <stdio.h>

int main() {
    int password;
    int a;
    int b;

    printf("IOLI Crackme Level 0x02\n");
    printf("Password: ");
    scanf("%d", &password);

    a = 90;
    b = 492;
    a += b;
    b = a * a;

    if (password == b)
        printf("Password OK :)\n");
    else
        printf("Invalid Password!\n");

    return 0;
}

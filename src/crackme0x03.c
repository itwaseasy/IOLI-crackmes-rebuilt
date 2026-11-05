#include <stdio.h>
#include <string.h>

void shift(const char* str) {
    char buffer[120];
    size_t i;

    for (i = 0; i < strlen(str); ++i) {
        buffer[i] = str[i] - 3;
    }
    buffer[i] = 0;

    printf("%s\n", buffer);
}

void test(int a, int b) {
    if (a != b)
        shift("Lqydolg#Sdvvzrug$");
    else
        shift("Sdvvzrug#RN$$$#=,");
}

int main() {
    int password;
    int a;
    int b;

    printf("IOLI Crackme Level 0x03\n");
    printf("Password: ");
    scanf("%d", &password);

    a = 90;
    b = 492;
    a += b;
    b = a * a;

    test(password, b);

    return 0;
}

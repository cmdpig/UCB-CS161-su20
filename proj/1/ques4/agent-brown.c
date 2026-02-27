#include <stdlib.h>
#include <string.h>
#include <stdio.h>

void flip(char *buf, const char *input)
{
  size_t n = strlen(input);
  int i;
  for (i = 0; i < n && i <= 64; ++i)
    buf[i] = input[i] ^ (1u << 5);
//int 和 unsigend int 都是4字节，所以1u << 5的结果是32，等价于将输入字符的第6位进行翻转。
  while (i < 64)
    buf[i++] = '\0';
}
//只要i>=64，循环就会停止，所以当输入字符串长度超过64时，buf数组就会发生缓冲区溢出，导致未定义行为。
void invoke(const char *in)
{
  char buf[64];
  flip(buf, in);
  puts(buf);
}

void dispatch(const char *in)
{
  invoke(in);
}

int main(int argc, char *argv[])
{
  if (argc != 2)
    return 1;

  dispatch(argv[1]);
  return 0;
}

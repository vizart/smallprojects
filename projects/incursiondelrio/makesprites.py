import math


class Sprite:
    def getPicRaw(self):
        return self.pic

    def getDirections(self):
        return ['ltr', 'rtl']

    def makeAll(self):
        for dir in self.getDirections():
            self.makeTable(dir)
            self.makeGroup(dir)

    def isWhite(self):
        return False

    def getSpriteName(self, orientation, shift):
        shiftstr = ['_inf'] + range(0,8) + ['_sup']
        return '%s_%s%s' % (self.getName(), orientation, shiftstr[shift+1])

    def spriteRange(self, orientation):
        return xrange([-1,0][orientation == 'rtl'],8) # [8,9][orientation == 'rtl'])

    def includeShift(self, shift):
        return True

    def makeTable(self, orientation):
        print '%s_%s_dispatch:' % (self.getName(), orientation)
        print '\n'.join(['\tdw %s' % self.getSpriteName(orientation, x) for x in self.spriteRange(orientation)])


    def makeGroup(self, orientation):
        print '%s_%s_spritegroup:' % (self.getName(), orientation)

        for shift in self.spriteRange(orientation):
            print '%s:' % self.getSpriteName(orientation, shift)
            if (self.includeShift(shift)):
                self.makeAsm(shift, orientation, self.getSpriteName(orientation, shift) + '_ret')
            else:
                print '  ; (shift %d skipped)' % shift
        print ';; end of sprite group %s' % self.getName()

    def makeAsm(self, shift, orientation, returnLabel):
        print '\tlxi h, 0'
        print '\tdad sp'
        print '\tshld %s+1' % returnLabel   
        #print '\t.nolist' 

        if not self.isWhite():
            layer = self.makeLayer('13578', shift, orientation)     # layer 0
            if (len(layer) > 0):
                print ';; layer 0 (8000)'
                print '\tmov h, d'        
                print '\tmov l, e'        
                print '\tsphl'
                print '\tlxi b, 0'
                print layer

            layer = self.makeLayer('2367', shift, orientation)      # layer 1
            if (len(layer) > 0):
                print ';; layer 1 (a000)'
                print '\tlxi h, $2000'
                print '\tdad d'
                print '\tsphl'
                print layer

            layer = self.makeLayer('4567', shift, orientation)        # layer 2
            if (len(layer) > 0):
                print ';; layer 2 (c000)'
                print '\tlxi h, $4000'
                print '\tdad d'
                print '\tsphl'
                print layer

            layer = self.makeLayer('8', shift, orientation)        # layer 3
            if (len(layer) > 0):
                print ';; layer 3 (e000)'
                print '\tlxi h, $6000'
                print '\tdad d'
                print '\tsphl'
                print layer
        else:
            # only white layer
            print '\txchg'        
            print '\tlxi d, $4000'
            print '\tdad d'
            print '\tsphl'
            print '\tlxi b, 0'
            print ';; white'
            print self.makeLayer('4', shift, orientation)    

        #print '\t.list'
        print '%s:' % returnLabel
        print '\tlxi sp, 0'
        print '\tret'

    def makeLayer(self, layerchar, shift, orientation):
        result = ''
        comment = ''

        pic = self.getPic(shift, 
                mirror = orientation == 'rtl', 
                prepend = shift == -1, 
                append = (shift == 0) and (orientation == 'rtl'))

        # pre-filter pic to find out its top and bottom boundaries

        boundsmap = map(lambda x: self.filter(x, layerchar), pic)
        for sss in zip(pic,boundsmap): 
            comment = comment + (';[%s] %010x\n' % sss)

        leading = self.countLeading(boundsmap, 0)/2
        trailing = self.countTrailing(boundsmap, 0)/2
        comment = comment + '; stripped pairs: leading: %d trailing: %d\n' % (leading,trailing)


        height = len(pic)
        width = len(pic[0])
        columns = width / 8

        lastb = -1

        # skip initial leading count
        if leading * 2 == height:
            return result
        if leading > 1:
            result = result + '\tlxi h, $%x\n' % (0xffff - (leading*2 - 1))
            result = result + '\tdad sp\n'
            result = result + '\tsphl\n'
        else:
            for i in xrange(0, leading):
                result = result + '\tpush b\n'


        for column in xrange(0,columns):
            for y in xrange(leading * 2, height - trailing * 2, 2):   
                popor = pic[y][column*8:column*8+8] + pic[y+1][column*8:column*8+8]
                b = self.filter(popor, layerchar)
                if b == 0:
                    result = result + '\tpush b\n'
                else:
                    if b != lastb:
                        result = result +('\tlxi h, $%04x\n' % b)
                        lastb = b
                    result = result + '\tpush h\n'
            if column != columns - 1:
                result = result + ('\tlxi h, 256+%d\n\tdad sp\n\tsphl\n' % (height - leading*2 - trailing * 2))
                lastb = -1

        return comment + result

    def getPic(self, shift, prepend = False, append = False, mirror = False):
        if (shift == -1): shift = 0
        unshifted = self.getPicRaw()
        if (self.isDoubleWidth()):
            unshifted = map(self.doublify, unshifted)
        if (mirror):  unshifted = map(lambda x: x[::-1], unshifted)
        if (prepend): unshifted = map(lambda x: ' '*8 + x, unshifted)
        if (append):  unshifted = map(lambda x: x + ' '*8, unshifted)
        if shift == 0:
            return unshifted
        else:
            return map(lambda x: ' '*shift + x + ' '*(8-shift), unshifted)
                
    def doublify(self, chars):
        return ''.join([x + x for x in chars])

    def isDoubleWidth(self):
        return False

    def filter(self, chars, charset):
        return reduce(lambda x,y: (x<<1)|y, [[0,1][x in charset] for x in chars])

    def countLeading(self, lst, match):
        lst = lst + [1]
        for i in xrange(len(lst)):
            if (lst[i] != match): 
                break
        return i

    def countTrailing(self, lst, match):
        for i in xrange(len(lst)):
            if (lst[len(lst) - 1 - i] != match): break
        return i
    

class BlitSprite(Sprite):
    def makeAsm(self, shift, orientation, returnLabel):
        print ".list"
        layer = self.makeLayer('4', shift, orientation)     
        if (len(layer) > 0):
            print ';; white pixels'
            print layer

    def makeLayer(self, layerchar, shift, orientation):
        result = ''
        comment = ''

        pic = self.getPic(shift, 
                mirror = orientation == 'rtl', 
                prepend = shift == -1, 
                append = (shift == 0))


        height = len(pic)
        width = len(pic[0])
        columns = width / 8

        result = '\tdw';

        for column in xrange(0,columns):
            for y in xrange(0, height, 2):   
                popor = pic[y][column*8:column*8+8] + pic[y+1][column*8:column*8+8]
                b = self.filter(popor, layerchar)
                result = ('%s $%04x,' % (result, b));

        result = result + '\n';
        return comment + result




class Ship(Sprite):
           #1   1   1   1   |
    pic = ['       66       ',
           '       66       ',
           '     6666       ',
           '   66666666     ',
           '2222222222222222',
           '222222222222222 ',
           '5555555555555   ',
           '  555555555     ']

    def isDoubleWidth(self):
        return True

    def getName(self):
        return "ship"

class Copter(Sprite):
    pic = ['       7777777  ',
           '77   77777777777',
           '77   77777777777',
           '6666666666666666', 
           '77     7777777  ', 
           '77     7777777  ',
           '         777    ',
           '       7777777  ']

    def isDoubleWidth(false):
        return False

    def getName(self):
        return "copter"

class RedCopter(Sprite):
    pic = ['       2222222  ',
           '22   22222222222',
           '22   22222222222',
           '3333333333333333', 
           '22     2222222  ', 
           '22     2222222  ',
           '         222    ',
           '       2222222  ']

    def isDoubleWidth(false):
        return False

    def getName(self):
        return "redcopter"


class PropellerA(Sprite):
    pic = ['     444444     ',
           '         4444444',
           '         4444444',
           '         444    ']

    def isDoubleWidth(false):
        return False

    def getName(self):
        return "propellerA"

    def isWhite(self):
        return True

class PropellerB(Sprite):
    pic = ['         4444444',
           '     4444444    ',
           '     4444444    ',
           '         444    ']

    def isDoubleWidth(false):
        return False

    def getName(self):
        return "propellerB"

    def isWhite(self):
        return True

class Jet(Sprite):
    pic = ['44              ',
           '4444      4444  ',
           '4444444444444444', 
           '  4444   4444444', 
           '      44444     ',
           '    4444        ']

    def isDoubleWidth(false):
        return False

    def isWhite(self):
        return True

    def getName(self):
        return "jet"

    def includeShift(self, shift):
        return shift in [-1, 0, 4]


class Bridge(Sprite):
    def isDoubleWidth(false):
        return True

    def isWhite(self):
        return False

    def getDirections(self): return ['ltr']

    def includeShift(self, shift):
        return shift in [0]

class BridgeTop(Bridge):
    pic = ['66              66            66',
           '666            6666          666',
           '66666666666666666666666666666666',
           '66666666666666666666666666666666',
           '63636363636363636363636363636363', 
           '36363636363636363636363636363636', 
           '63636363636363636363636363636363', 
           '36363636363636363636363636363636', 
           '63636363636363636363636363636363', 
           '36363636363636363636363636363636', 
           '63636363636363636363636363636363', 
           '36363636363636363636363636363636', 
           '66666666666666666666666666666666',
           '33333333333333333333333333333333']

    def getName(self):
        return "bridgeTop"


class BridgeBottom(Bridge):
    pic = ['33333333333333333333333333333333', 
           '66666666666666666666666666666666',
           '36363636363636363636363636363636', 
           '63636363636363636363636363636363', 
           '36363636363636363636363636363636', 
           '63636363636363636363636363636363', 
           '36363636363636363636363636363636', 
           '63636363636363636363636363636363', 
           '36363636363636363636363636363636', 
           '63636363636363636363636363636363', 
           '66666666666666666666666666666666',
           '66666666666666666666666666666666',
           '666            6666          666',
           '66              66            66'];

    def getName(self):
        return "bridgeBottom"

class Fuuuu(Sprite):
    pic = ['   2222222222   ',
           '  22        22  ',
           '  22  22222222  ',
           '  22     22222  ',
           '  22  22222222  ',
           '  22  22222222  '];

    def getDirections(self): return ['ltr']

    def includeShift(self, shift):
        return shift in [0]

    def getName(self): return "fuuuu"

class Uuuuu(Sprite):
    pic = ['  444444444444  ',
           '  44  4444  44  ',
           '  44  4444  44  ',
           '  44  4444  44  ',
           '  44        44  ',
           '  444444444444  '];

    def getDirections(self): return ['ltr']

    def includeShift(self, shift):
        return shift in [0]

    def getName(self): return "uuuuu"

class Euuuu(Sprite):
    pic = ['  22        22  ',
           '  22  22222222  ',
           '  22      2222  ',
           '  22  22222222  ',
           '  22        22  ',
           '  222222222222  '];

    def getDirections(self): return ['ltr']

    def includeShift(self, shift):
        return shift in [0]

    def getName(self): return "euuuu"

class Luuuu(Sprite):
    pic = ['  44  44444444  ',
           '  44  44444444  ',
           '  44  44444444  ',
           '  44  44444444  ',
           '  44        44  ',
           '  444444444444  '];

    def getDirections(self): return ['ltr']

    def includeShift(self, shift):
        return shift in [0]

    def getName(self): return "luuuu"



class PlayerStraight(BlitSprite):
    pic = ['       44       ',
           '       44       ',
           '       44       ',
           '      4444      ',
           '     444444     ',
           '    44444444    ',
           '   444 44 444   ',
           '   44  44  44   ',
           '      4444      ',
           '     444444     ',
           '    44 44 44    ',
           '                '];

    def getName(self): return "player_up"

    def getDirections(self): return ['ltr']

class PlayerBank(BlitSprite):
    pic = ['       44       ',
           '       44       ',
           '       44       ',
           '      444       ',
           '     44444      ',
           '    444444      ',
           '   444 4444     ',
           '       44444    ',
           '       44 44    ',
           '      444       ',
           '     44444      ',
           '        444     '];

    def getName(self): return "player_bank"

#class PlayerBankR(PlayerBank):
#    def getName(self): return "player_br"
#
#class PlayerBankL(PlayerBank):
#    def getName(self): return "player_bl"



        
print ';; Automatically generated file'
print ';; see makesprites.py'
#print '.nolist'

a = Ship()
a.makeAll()

a = Copter()
a.makeAll()

RedCopter().makeAll()

PropellerA().makeAll()
PropellerB().makeAll()
Jet().makeAll()
BridgeTop().makeAll()
BridgeBottom().makeAll()
Fuuuu().makeAll()
Uuuuu().makeAll()
Euuuu().makeAll()
Luuuu().makeAll()
PlayerStraight().makeAll()
PlayerBank().makeAll()
print '.list'



# $Id: creation.t,v 1.5 2003/01/24 12:29:58 ilja Exp $

use warnings;
use strict;

use Test;
BEGIN 
{     
    use vars qw(@tests $testqueue);
    @tests = ( \&test_open, 
               \&test_unlink, 
               \&test_name, 
               \&test_attributes,
               \&test_blocking );
    $testqueue = '/testq_42';
    
    plan tests => scalar @tests;
};

use Fcntl;
use POSIX::RT::MQ;

for (@tests) { ok $_->() }



sub test_open
{
    POSIX::RT::MQ->unlink($testqueue);
    my ($mq, $result);
    {
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR)            and last;
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT)    or  last;
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR)            or  last;
        $mq = POSIX::RT::MQ->open($testqueue, O_RDONLY)          or  last;
        $mq = POSIX::RT::MQ->open($testqueue, O_WRONLY)          or  last;
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_NONBLOCK) or  last;
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT|O_EXCL) and  last;

        $result = 1;
    }        

    $result;
}    

sub test_unlink
{
    POSIX::RT::MQ->unlink($testqueue);
    my ($mq, $result);
    {
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT)    or  last;
        $mq->unlink()                                        or  last;
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT)    or  last;    
        POSIX::RT::MQ->unlink($testqueue)                        or  last;
        $mq->unlink()                                        and last;
        POSIX::RT::MQ->unlink($testqueue)                        and last;
       
        $result = 1;
    }
    $result;
}

sub test_name
{
    POSIX::RT::MQ->unlink($testqueue);
    my ($mq, $result);
    {
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT)    or  last;
        $mq->name eq $testqueue                              or  last;
        $mq->unlink()                                        or  last;
        defined($mq->name())                                 and last;
        
        $result = 1;
    }
    $result;
}
        
sub test_attributes
{
    POSIX::RT::MQ->unlink($testqueue);
    my ($mq, $result, $a1, $a2);
    {
        $a1 = { mq_maxmsg=>128, mq_msgsize=>256 };
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT, 0600, $a1) or  last;
        $a2 = $mq->attr                                              or  last; 
        ($a2->{mq_maxmsg}  == $a1->{mq_maxmsg})                      or  last;
        ($a2->{mq_msgsize} == $a1->{mq_msgsize})                     or  last;
        ($a2->{mq_curmsgs} == 0)                                     or  last;
        ($a2->{mq_flags} & O_NONBLOCK)                               and last;
        
        $a1->{mq_flags} = $a2->{mq_flags} | O_NONBLOCK;
        $mq->attr($a1)                                               or  last;
        $a2 = $mq->attr                                              or  last;         
        ($a2->{mq_flags} & O_NONBLOCK)                               or  last;

        $result = 1;
    }
    $result;
}    

sub test_blocking
{
    POSIX::RT::MQ->unlink($testqueue);
    
    my ($mq, $result, $a, $bl);
    {
        $a = { mq_maxmsg=>128, mq_msgsize=>256 };
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT, 0600, $a) or  last;

        # blocking mode here ...

        defined($bl = $mq->blocking)                                 or  last;
        $a = $mq->attr                                               or  last; 
        ($bl && !($a->{mq_flags} & O_NONBLOCK))                      or  last;

        $bl == $mq->blocking(0)                                      or  last;

        defined($bl = $mq->blocking)                                 or  last;
        $a = $mq->attr                                               or  last; 
        (!$bl && $a->{mq_flags} & O_NONBLOCK)                        or  last;

        $bl == $mq->blocking(1)                                      or  last;

        defined($bl = $mq->blocking)                                 or  last;
        $a = $mq->attr                                               or  last; 
        ($bl && !($a->{mq_flags} & O_NONBLOCK))                      or  last;

        $result = 1;
    }
    $result;

}

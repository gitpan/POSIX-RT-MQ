# $Id: trnotify.t,v 1.2 2003/01/24 13:32:36 ilja Exp $

use warnings;
use strict;

use Test;
BEGIN 
{     
    use vars qw(@tests $testqueue $attr $msg $prio);
    @tests = ( \&test_sighash );
    $testqueue = '/testq_42';
    $attr = { mq_maxmsg=>16, mq_msgsize=>256 };
    ($msg, $prio) = ("A Sample Message!", 1);

    plan tests => scalar(@tests);
};

use Fcntl;
use POSIX;
use POSIX::RT::MQ;

for (@tests) { ok $_->() }
 


sub test_sighash
{
    POSIX::RT::MQ->unlink($testqueue);
    my $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT, 0600, $attr) or warn("open: $!\n"), return 0;
    
    $mq->notify()  and  warn("shouldn't be registered to notifications\n"), return 0;

    my $got_usr1 = 0;
    local $SIG{USR1} = sub { $got_usr1 = 1 };
    $mq->notify(SIGUSR1)  or  warn "cannot notify(SIGUSR1): $!\n";

    defined(my $pid = fork)  or warn("cannot fork: $!\n"), return 0;
    unless ($pid) #child...
    {
        undef $mq;
        $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_NONBLOCK)  or  exit(1);
        exit ($mq->send($msg, $prio) ? 0 : 2);
    }

    # wait until the child puts a message on the queue and terminates
    waitpid($pid, 0);
    # ok, if we still didn't get the notification let's give the system one more second
    $got_usr1  or  select(undef, undef, undef, 1);

    $got_usr1  or  warn("didn't get the SIGUSR1 :-(\n"), return 0;
    # really got a message?
    defined $mq->blocking(0)        or  warn("cannot blocking(0): $!\n"), return 0;
    my ($m, $p) = $mq->receive()    or  warn("cannot receive(): $!\n"), return 0;
    ($m eq $msg  &&  $p == $prio)   or  warn("unexpected message received\n"), return 0;

    # now we should be alredy deregistered from notifications
    $mq->notify()  and  warn("should be alredy deregistered from notifications\n"), return 0;

    1;
}


# $Id: transfer.t,v 1.4 2003/01/23 09:01:22 ilja Exp $

use warnings;
use strict;

use Test;
BEGIN 
{     
    use vars qw(@tests $testqueue @q_len @msg_len);
    @tests = ( \&test_integrity,
               \&test_nonblocking,
               \&test_blocking );
    @q_len    = (1, 10, 128);
    @msg_len  = (1, 128, 1024, 4096);
    $testqueue = '/testq_42';
    
    plan tests => scalar(@tests);
};

use Fcntl;
use POSIX::RT::MQ;

for (@tests) { ok $_->() }
 


sub test_integrity
{
    for my $q_len (@q_len)
    {
        for my $msg_len (@msg_len)
        {
            my $attr = { mq_maxmsg=>$q_len, mq_msgsize=>$msg_len };

            POSIX::RT::MQ->unlink($testqueue);
            my $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT, 0600, $attr) or warn("open: $!\n"), return 0;

            my @messages = ();
            for (my $m=0; $m<$q_len; $m++)
            {
                my ($msg, $prio) = construct_message($msg_len, $m);
                push @messages, [$msg, $prio, $m];
                $mq->send($msg, $prio) or warn("send: $!\n"), return 0;
            }
            @messages = sort { ($b->[1]<=>$a->[1]) || ($a->[2]<=>$b->[2]) } @messages;
            for (my $m=0; $m<$q_len; $m++)
            {
                my ($msg,  $prio)  = $mq->receive or warn("receive: $!\n"), return 0;
                my $saved = shift @messages;
                $msg eq $saved->[0] && $prio == $saved->[1] or warn("unexpected message\n"), return 0;
            }
       }
    }       
    1;
}    

sub test_nonblocking
{
    my $q_len   = $q_len[-1];
    my $msg_len = $msg_len[-1];
    my $attr = { mq_maxmsg=>$q_len, mq_msgsize=>$msg_len };
    
    POSIX::RT::MQ->unlink($testqueue);
    my $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT|O_NONBLOCK, 0600, $attr) or warn("open: $!\n"), return 0;
    
    # receive from empty queue
    $mq->receive and warn("receive from empty queue\n"), return 0;
    
    # fill the queue        
    for (my $m=0; $m<$q_len; $m++)
    {
        my ($msg, undef) = construct_message($msg_len, $m);
        $mq->send($msg) or warn("send: $!\n"), return 0;
    }
    
    # send to full queue
    my ($msg, undef) = construct_message($msg_len, 0);
    $mq->send($msg) and warn("send to full queue\n"), return 0;
    
    1;      
}

sub test_blocking
{
    my $q_len   = $q_len[-1];
    my $msg_len = $msg_len[-1];
    my $attr    = { mq_maxmsg=>$q_len, mq_msgsize=>$msg_len };
    
    POSIX::RT::MQ->unlink($testqueue);
    my $mq = POSIX::RT::MQ->open($testqueue, O_RDWR|O_CREAT, 0600, $attr) or warn("open: $!\n"), return 0;
    
    # receive from empty queue
    {
        my $timeout = '';
        local $SIG{ALRM} = sub { $timeout = 'TIMEOUT' };
        alarm(5);
        $mq->receive;
        $timeout eq 'TIMEOUT' or warn("receive didn't block\n"), return 0;
    }

    # fill the queue    
    for (my $m=0; $m<$q_len; $m++)
    {
        my ($msg, undef) = construct_message($msg_len, $m);
        $mq->send($msg) or warn("send: $!\n"), return 0;
    }
    
    # send to full queue
    {
        my $timeout = '';
        local $SIG{ALRM} = sub { $timeout = 'TIMEOUT' };
        my ($msg, undef) = construct_message($msg_len, 0);
        alarm(5);
        $mq->send($msg) and warn("send to full queue\n"), return 0;
        $timeout eq 'TIMEOUT' or warn("send didn't block\n"), return 0;
    }
    
    1;      
}

sub construct_message
{
    my $msg_len = shift;
    my $msg_num = shift;
    my $all_chars = join '' => map { chr } (0..255);

    my $msg = "$msg_num ";
    $msg .= $all_chars  while length($msg) < $msg_len;
    substr($msg, $msg_len) = '';
    ($msg, $msg_num%8); # calculate prio
}

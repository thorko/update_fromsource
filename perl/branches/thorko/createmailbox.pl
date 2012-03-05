#!/usr/bin/perl -w
#
# This will create a new mailbox and set a quota on the new user. Just be 
# sure that you installed the Cyrus::IMAP perl module.  If you did 
# 'make all && make install' or installed Cyrus using the FreeBSD ports you
# don't have to do anything at all.
#
# Change the params below to match your mailserver settins, and
# your good to go!
#
# Author: amram@manhattanprojects.com
#
# modified by Tom Lazar tom@tomster.org on 2003-08-26 to use
# a tab separated user - passwd inputfile instead of the standardpassword

use Cyrus::IMAP::Admin;

#
# CONFIGURATION PARAMS
#
my $cyrus_server = "localhost";
my $cyrus_user = "youruser";
my $cyrus_pass = "yourpass";

# 100 Megs
my $quota_size = "1000000";

my $mechanism = "login";

#
# EOC
#

if (!$ARGV[0]) {
  die "Usage: $0 [user to add] passwd \n";
} else {
  $newuser = "$ARGV[0]";
  $newpasswd = "$ARGV[1]";    
}

sub createMailbox {

  my ($user, $subfolder) = @_;

  my $cyrus = Cyrus::IMAP::Admin->new($cyrus_server);
  $cyrus->authenticate($mechanism,'imap','',$cyrus_user,'0','10000',$cyrus_pass);

  if ($subfolder eq "INBOX") {
    $mailbox = "user.". $user;
  } else {
    $mailbox = "user.". $user .".". $subfolder;
  } 

  $cyrus->create($mailbox);
  if ($cyrus->error) {
    print STDERR "Error: ", $mailbox," ", $cyrus->error, "\n";
  } else {
    print "Created Mailbox: $mailbox \n";
  }

}

sub setQuota {

  my ($user) = @_;

  my $cyrus = Cyrus::IMAP::Admin->new($cyrus_server);
  $cyrus->authenticate($mechanism,'imap','',$cyrus_user,'0','10000',$cyrus_pass);
  
  $mailbox = "user.". $user;
  $cyrus->setquota($mailbox,"STORAGE",$quota_size);
  if ($cyrus->error) {
    print STDERR "Error: ", $mailbox," ", $cyrus->error, "\n";
  } else {
    print "Setting Quota: $mailbox at $quota_size \n";
  }

}

print "Adding User: ", $newuser, "\n";

createMailbox($newuser,'INBOX');
createMailbox($newuser,'Sent');
createMailbox($newuser,'Trash');
createMailbox($newuser,'Drafts');
createMailbox($newuser,'Junk');

setQuota($newuser);

# This portion below will set a password for the user you wanted to 
# add.  

system "echo ". $newpasswd ." > .saslpass.tmp";
system "saslpasswd2 -p $newuser < .saslpass.tmp";
print "Generated Password: Completed \n";
unlink(".saslpass.tmp");


# -*-Perl-*-

##############################################
# Copyright (C) 2000 Craig S. Pohl
# Washington University, St. Louis
# All Rights Reserved.
##############################################

######################################
# TouchScreen Interface Data Manager #
######################################

package TouchScreen::TouchMgr;

use strict;

#############################################################
# Methods to be exported
#############################################################

require Exporter;

our @ISA = qw (Exporter);
our @EXPORT = qw ( );

########################################
# Create new data management structure #
########################################
sub new {

    my ($class) = @_;

    my ($self) = {};
    bless $self, $class;

    $self -> {'TouchMgr'} = {};
    
    $self -> {'SeqNum'} = 0;

    my $screen_info = $self -> {'ScreenInfo'} = {};
    
    return $self;
} #new

sub AddScreen {
    
    # Input
    my ($self, $screencode, $autocode, $autoscreen) = @_;
    my $screenmgr = $self->{'TouchMgr'};
    my $seq_num = $self->GetSeqNum;
  


    my $prescreen_code = $screenmgr->{$seq_num}->{'ScreenCode'};
    
    if($seq_num >  0) {
	if($prescreen_code eq $screencode) {
	    return;
	}
    }
	
    my $num = $self -> GetSeqNumIncr;
    my $screen_ref = $screenmgr->{$num}={};
    
    $screen_ref->{'ScreenCode'} = $screencode;
    $screen_ref->{'AutoScreen'} = $autoscreen;
    $screen_ref->{'AutoCode'} = $autocode;
    
    return $screen_ref;

}

sub GetSeqNumIncr {

    my ($self) = @_;

    my $seqnum = $self -> {'SeqNum'};
    my $incr = $seqnum+1;
    $self -> {'SeqNum'} = $incr;
    return $seqnum;
}
sub GetSeqNum {

    my ($self) = @_;
    my $seqnum = $self -> {'SeqNum'};
    $seqnum--;
    return $seqnum;
}
sub GetSeqNumDec {

    my ($self) = @_;

    my $seqnum = $self -> {'SeqNum'};
    my $dec=$seqnum-1;
    $self -> {'SeqNum'} = $dec;

    return $dec;
}


sub GetAutoCode {

    my ($self) = @_;
    
    my $screenmgr = $self -> {'TouchMgr'};

    my $seqnum = $self -> GetSeqNum;
    my $autocode = $screenmgr -> {$seqnum} -> {'AutoCode'};
   
    return $autocode;
    
} #GetAutoCode


sub GetAutoScreen {

    my ($self) = @_;
    
    my $screenmgr = $self -> {'TouchMgr'};

    my $seqnum = $self -> GetSeqNum;
    
    my $autocode = $screenmgr -> {$seqnum} -> {'AutoScreen'};
   
    return $autocode;
    
} #GetAutoScreen


sub PreviousScreen {

    my ($self) = @_;
    
    my $screenmgr = $self -> {'TouchMgr'};

    my $seqnum = $self -> GetSeqNumDec;
    undef($screenmgr -> {$seqnum});

    $seqnum = $self -> GetSeqNumDec;
    my $screencode = $screenmgr -> {$seqnum} -> {'ScreenCode'};
    
    &$screencode if(defined $screencode);
   
    
} #PreviousScreen

sub Restart {

    my ($self) = @_;
        
    undef $self -> {'TouchMgr'};
    $self -> {'TouchMgr'}={};
    $self -> {'SeqNum'} = 0;

} #Destroy

sub SetUserId {

    my ($self, $id) = @_;
    
    $self -> {'UnixLogin'} = $id;
}

sub SetScreenInfo {

    my ($self, $object,  $id) = @_;
    
    my $screen_info = $self -> {'ScreenInfo'};

    $screen_info -> {$object} = $id;
}

sub GetScreenInfo {

    my ($self, $object) = @_;

    my $info = $self -> {'ScreenInfo'} -> {$object};

    return $info;
}

1;

# $Header$

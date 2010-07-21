#$Id$

package PAP::Command::PsortB;

use strict;
use warnings;

#use Workflow;

use Bio::Seq;
use Bio::SeqIO;
use Bio::SeqFeature::Generic;

use English;
use File::Temp;
use IO::File;
use IPC::Run;


class PAP::Command::PsortB {
    is  => ['PAP::Command'],
    has => [
        fasta_file      => { 
                            is  => 'SCALAR', 
                            doc => 'fasta file name' ,
                            is_input => 1,
                           },
        gram_stain      => {
                            is  => 'SCALAR',
                            doc => 'gram stain (positive/negative)',
                            is_input => 1,
                           },
        bio_seq_feature => { 
                            is          => 'ARRAY', 
                            is_optional => 1,
                            doc         => 'array of Bio::Seq::Feature', 
                            is_output => 1,
                           },
        lsf_queue => { is_param => 1, default_value => 'short', },
        lsf_resource => { is_param => 1, default_value => "-R 'select[type==LINUX86] rusage[tmp=100]'", },
    ],
};

sub sub_command_sort_position { 10 }

sub help_brief {
    "Run psort-b";
}

sub help_synopsis {
    return <<"EOS"
EOS
}

sub help_detail {
    return <<"EOS"
Need documenation here.
EOS
}

sub execute {

    my $self = shift;
    
    
    my $fasta_file  = $self->fasta_file();
    my $gram_stain  = $self->gram_stain();

    if ($gram_stain eq 'positive') {
        $gram_stain = '-p';
    }
    elsif ($gram_stain eq 'negative') {
        $gram_stain = '-n';
    }
    else {
        die "gram stain should be positive or negative, not '$gram_stain'";
    }

    my $temp_fh = File::Temp->new();
    my $temp_fn = $temp_fh->filename();
    $temp_fh->close();
    
    my @psortb_command = (
                          'psort-b',
                          $gram_stain, 
                          '-o',
                          'terse',
                          $fasta_file,
                      );
    
    my ($psortb_err);

    IPC::Run::run(
                  \@psortb_command,
                  \undef,
                  '>',
                  $temp_fn,
                  '2>',
                  \$psortb_err,
              ) || die "psort-b failed: $CHILD_ERROR";
    
    my $feature_ref = $self->parse_psortb_terse($temp_fn);
    
    $self->bio_seq_feature($feature_ref);
    
}

sub parse_psortb_terse {
    
    my ($self, $psort_fn) = (@_);
    
    
    my @features = ( );

    my $psort_fh = IO::File->new();
    $psort_fh->open("$psort_fn") or die "Can't open '$psort_fn': $OS_ERROR";

    LINE: while (my $line = <$psort_fh>) {

        chomp $line;
        
        if ($line =~ /^SeqID/) {
            next;
        }
        
        my ($gene, $class, $score) = split(/\t/,$line);
        $gene =~ s/\s$//; # psort-b has been appending a space to this...

        if ($class =~ /unknown/i) { next LINE; }
        
        my $feature = Bio::SeqFeature::Generic->new(
                                                    -display_name => $gene,
                                                );

        $feature->add_tag_value('psort_localization', $class);
        $feature->add_tag_value('psort_score', $score);
        
        push @features, $feature;
        
    }

    return \@features;
    
}

1;

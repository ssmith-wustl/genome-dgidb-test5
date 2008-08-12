#$Id$

package PAP::Command::PsortB;

use strict;
use warnings;

use Workflow;

use Bio::Annotation::SimpleValue;
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
                           },
        gram_stain      => {
                            is  => 'SCALAR',
                            doc => 'gram stain (positive/negative)',
                           },
        bio_seq_feature => { 
                            is          => 'ARRAY', 
                            is_optional => 1,
                            doc         => 'array of Bio::Seq::Feature', 
                           },
    ],
};

operation PAP::Command::PsortB {
    input  => [ 'fasta_file', 'gram_stain' ],
    output => [ 'bio_seq_feature' ],
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
              );
    
    my $feature_ref = $self->parse_psortb_terse($temp_fn);
    
    $self->bio_seq_feature($feature_ref);
    
}

sub parse_psortb_terse {
    
    my ($self, $psort_fn) = (@_);
    
    
    my @features = ( );

    my $psort_fh = IO::File->new();
    $psort_fh->open("$psort_fn") or die "Can't open '$psort_fn': $OS_ERROR";

    while (my $line = <$psort_fh>) {

        chomp $line;
        
        if ($line =~ /^SeqID/) {
            next;
        }
        
        my ($gene, $class, $score) = split(/\t/,$line);

        unless ($score >= 7.5) {
            next;
        }

        my $feature = Bio::SeqFeature::Generic->new(
                                                    -display_name => $gene,
                                                );

        my $annotation_collection = $feature->annotation();

        my $sv = Bio::Annotation::SimpleValue->new(-value => $class);

        $annotation_collection->add_Annotation('cellular_localization' => $sv);

        push @features, $feature;
        
    }

    return \@features;
    
}

1;

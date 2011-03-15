# FIXME ebelter
#  remove
#
package Genome::Model::Command::List::VariationsForAmplicons;

use strict;
use warnings;

use Genome;
use Data::Dumper;
use IO::File;

class Genome::Model::Command::List::VariationsForAmplicons
{
    is => 'Genome::Model::Command',
    has => [
        model_id => 
        {
            is => 'Integer',
            is_optional => 0,
        },
        primer_file => 
        {
            is => 'String',
            is_optional => 0,
        },
    ],
    doc => 'list variations in the amplification region of a given primer file'
};

sub sub_command_sort_position { 9 }

sub help_synopsis {
    return; 
}

sub help_detail {
    return <<"EOS"
EOS
}

sub execute {
    my $self = shift;

    my $model = Genome::Model->get($self->model_id);
    $self->error_message( sprintf('Can\'t get model for model id (%s)', $self->model_id) )
        and return unless $model;

    my $primer_file = $self->primer_file;
    $self->error_message( sprintf('Can\'t get model for model id (%s)', $self->model_id) )
        and return unless -s $primer_file;
    my $fh = IO::File->new("< $primer_file");
    $self->error_meassage("Can't open file ($primer_file)")
        and return unless $fh;

    while ( my $primer = $fh->getline )
    {
        next if $primer =~ /^\s*$/;
        $primer =~ s/\s+//g;
        chomp $primer;
        my @primer_tags = GSC::Sequence::Tag->get
        (
            ref_id => 
            {
                operator => 'like', 
                value => $primer . '.%' 
            },
            sequence_item_type => 'primer sequence tag',
        );
        $self->status_message("No primer sequence tag found for pattern ($primer.%)")
            and next unless @primer_tags; # ERROR?

        for my $primer_tag ( @primer_tags )
        {
            my ($correspondence) = GSC::Sequence::Correspondence->get
            (
                scrr_id => $primer_tag->stag_id,
                scrr_type => 'primer sequence tag',
            );
            $self->status_message
            (
                sprintf('No correspondence found for primer tag ($primer)', $primer_tag->id )
            ) and next unless $correspondence; # ERROR?

            my ($chromosome) = GSC::Sequence::Chromosome->get(seq_id => $correspondence->seq2_id);
            $self->error_message
            (
                sprintf('No chromosome found for primer corresspondence (%s)', $correspondence->id)
            ) and return unless $chromosome;

            my $chromosome_name = $chromosome->chromosome;
            my ($snp_file) = $model->_variant_detail_files($chromosome_name);
            $self->status_message("Can't find snp file for chromosome ($chromosome_name)")
                and next unless defined $snp_file and -s $snp_file;

            printf
            (
                "###########\nPrimer: %s on %s goes from %s to %s\nLooking in %s\n", 
                $primer_tag->ref_id,
                $chromosome_name,
                $correspondence->seq2_start,
                $correspondence->seq2_stop,
                $snp_file
            );

            for my $position ( $correspondence->seq2_start..$correspondence->seq2_stop )
            {
                #print $position,"\n";
                #system "grep $position $snp_file";
                my @grep = `grep $position $snp_file`;
                next unless @grep;
                print "** Found snp!!: $grep[0]";
            }
        }
    }

    $fh->close;

    return 1;
}

1;

#$HeadURL$
#$Id$

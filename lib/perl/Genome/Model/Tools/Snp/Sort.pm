package Genome::Model::Tools::Snp::Sort;

use strict;
use warnings;

use Genome;
use Command;
use IO::File;
use Sort::Naturally qw| nsort |;

class Genome::Model::Tools::Snp::Sort {
    is => 'Command',
    has => [
            snp_file => {
                         type => 'String',
                         is_optional => 0,
                         doc => "maq cns2snp output",
                         shell_args_position => 1,
                     },
    ],
    has_optional => [
                     output_file => {
                                     type => 'Text',
                                     doc => 'optional output file',
                                 },
              ],
};

sub help_brief {
    "Sorts a SNP file using Sort::Naturally to sort the chromosomes";
}

sub help_detail {
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    return unless $self;

    unless (Genome::Sys->validate_file_for_reading($self->snp_file)) {
        $self->error_message('Failed to validate snp file '. $self->snp_file .'  for reading.');
        return;
    }
    if ($self->output_file) {
        unless (Genome::Sys->validate_file_for_writing($self->output_file)) {
            $self->error_message('Failed to validate output file '. $self->output_file .' for writing.');
            return;
        }
    }
    return $self;
}

sub execute {
    my $self=shift;

    my $snp_fh = Genome::Sys->open_file_for_reading($self->snp_file);
    my $output_fh;
    if ($self->output_file) {
        $output_fh = Genome::Sys->open_file_for_writing($self->output_file);
    } else {
        $output_fh = IO::Handle->new;
        $output_fh->fdopen(fileno(STDOUT),'w');
    }

    my %snp_at;
    while(my $line = $snp_fh->getline) {
        my ($chr, $pos,) = split /\t/, $line;
        $snp_at{$chr}{$pos} = $line;
    }
    $snp_fh->close;
    for my $chr (nsort keys %snp_at) {
        for my $pos (sort { $a <=> $b } keys %{$snp_at{$chr}}) {
            print $output_fh $snp_at{$chr}{$pos};
        }
    }
    $output_fh->close;
    return 1;
}


1;





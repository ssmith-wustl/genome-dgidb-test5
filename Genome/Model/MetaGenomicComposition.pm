package Genome::Model::MetaGenomicComposition;

use strict;
use warnings;

use Genome;

use Data::Dumper;
use File::Grep 'fgrep';
use Genome::Consed::Directory;
use Genome::ProcessingProfile::MetaGenomicComposition;
use POSIX 'floor';

class Genome::Model::MetaGenomicComposition {
    is => 'Genome::Model',
    has => [
    map({
            $_ => {
                via => 'processing_profile',
            }
        } Genome::ProcessingProfile::MetaGenomicComposition->params_for_class
    ),
    ],
};

#< Misc >#
sub build_subclass_name {
    return 'meta-genomic-composition';
}

#< Dirs >#
sub consed_directory { #TODO put this on class def
    my $self = shift;

    return $self->{_consed_dir} if $self->{_consed_dir};
    
    $self->{_consed_dir} = Genome::Consed::Directory->create(directory => $self->data_directory);
    $self->{_consed_dir}->create_consed_directory_structure; # TODO put in create

    return $self->{_consed_dir};
}

sub primer_directory {
    return '/gscmnt/839/info/medseq/meta-genomic-composition-primers';
}

#< Files >#
sub _fasta_file_name {
    my ($self, $type) = @_;

    return sprintf(
        '%s/%s.%s.fasta',
        $self->consed_directory->directory,
        $self->subject_name,
        $type,
    );
}

sub all_assembled_fasta {
    return _fasta_file_name(@_, 'assembled');
}

sub all_pre_process_input_fasta {
    return _fasta_file_name(@_, 'pre_process_input');
}

sub all_assembly_input_fasta {
    return _fasta_file_name(@_, 'assembly_input');
}

sub metrics_file {
    my $self = shift;

    return sprintf('%s/%s.metrics.txt', $self->data_directory, $self->subject_name);
}

sub quality_histogram_file {
    my $self = shift;

    return sprintf('%s/%s.histogram.png', $self->data_directory, $self->subject_name);
}

#< Determining subclones >#
sub subclones_and_traces_for_assembly {
    my $self = shift;

    my $method = sprintf('_determine_subclones_in_chromat_dir_%s', $self->sequencing_center);
    my $subclones = $self->$method;
    unless ( $subclones and %$subclones ) {
        $self->error_message(
            sprintf('No subclones found in chromat_dir of model (%s)', $self->name) 
        );
        return;
    }

    return $subclones;
}

sub subclones {
    my $self = shift;

    my $subclones = $self->subclones_and_traces_for_assembly
        or return;

    return [ sort { $a cmp $b } %$subclones ];
}

sub subclones_and_headers { 
    my $self = shift;

    my $subclones_and_traces = $self->subclones_and_traces_for_assembly
        or return;

    my $header_generator= sub{
        return sprintf(">%s\n", $_[0]);
    };
    if ( $self->name =~ /ocean/i ) {
        my @counters = (qw/ -1 Z Z /);
        $header_generator = sub{
            if ( $counters[2] eq '9' ) {
                $counters[2] = 'A';
            }
            elsif ( $counters[2] eq 'Z' ) {
                $counters[2] = '0';
                if ( $counters[1] eq '9' ) {
                    $counters[1] = 'A';
                }
                elsif ( $counters[1] eq 'Z' ) {
                    $counters[1] = '0';
                    $counters[0]++; # Hopefully we won't go over Z
                }
                else {
                    $counters[1]++;
                }
            }
            else {
                $counters[2]++;
            }

            return sprintf(">%s%s%s%s\n", $self->subject_name, @counters);
        };
    }

    my %subclones_and_headers;
    for my $subclone ( sort { $a cmp $b } keys %$subclones_and_traces ) {
        $subclones_and_headers{$subclone} = $header_generator->($subclone);
    }

    return \%subclones_and_headers;
}

sub _determine_subclones_in_chromat_dir_gsc {
    my $self = shift;

    my $dh = $self->_open_directory( $self->consed_directory->chromat_dir )
        or return;

    my %subclones;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz##;
        $scf =~ /^(.+)\.[bg]\d+$/
            or next;
        push @{$subclones{$1}}, $scf;
    }
    $dh->close;

    return \%subclones;
}

sub _determine_subclones_in_chromat_dir_broad {
    my $self = shift;

    my $dh = $self->_open_directory( $self->consed_directory->chromat_dir )
        or return;

    my %subclones;
    while ( my $scf = $dh->read ) {
        next if $scf =~ m#^\.#;
        $scf =~ s#\.gz$##;
        my $subclone = $scf;
        $subclone =~ s#\.T\d+$##;
        $subclone =~ s#[FR](\w\d\d?)$#\_$1#; # or next;

        push @{$subclones{$subclone}}, $scf;
    }
    
    return  \%subclones;
}

sub _open_directory {
    my ($self, $dir) = @_;

    my $dh = IO::Dir->new($dir);

    return $dh if $dh;

    $self->error_message("Can't open directory ($dir)");
    
    return;
}

############################################
#
# Need to do something about this

sub header_for_subclone {
    my ($self, $subclone) = @_;

    return ">$subclone\n" unless $self->name =~ /ocean/i;

    $subclone =~ s/^HMPB\-//;
    my ($match) = fgrep { /$subclone/ } "/gsc/var/lib/pwb/ocean_lookup_for_genome_model.txt"; 
    my ($line) = values %{$match->{matches}};

    unless ( $line ) { 
        $self->error_message("Can't determine subscript code for subclone ($subclone)");
        return;
    }

    chomp $line;
    my ($ss) = (split(/\s+/, $line))[2];
    
    return sprintf(">%s%s\n", $self->subject_name, $ss);
}

1;

=pod
=cut

#$HeadURL$
#$Id$

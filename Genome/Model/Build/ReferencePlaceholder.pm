package Genome::Model::Build::ReferencePlaceholder;

use strict;
use warnings;

use Genome;
use File::Basename;

# This class is an OO-representation of the reference used for reference alignments.
# It will be replaced with a real model once we have one in place for all reference sequences used.
# For now reference alignment models just make this upon first call to the accessor.

class Genome::Model::Build::ReferencePlaceholder {
    id_by => [
        name            => { is => 'Text' },
    ],
    has => [
        sample_type     => {
                            is => 'Text',
                            is_optional => 1,
                            default_value => 'dna'
                        },
        data_directory  => { is => 'Text' },
    ],
    doc => 'Temporary object representing the reference used in reference alignment models.  To be replaced with a real model build.',
};

sub get {
    my $class = shift;
    my $bx = $class->get_boolexpr_for_params(@_);
    my %p = $bx->params_list;
    unless ($p{id} || $p{name}) {
        die __PACKAGE__ . ' can only be gotten by name!';
    }
    my $obj = $class->SUPER::get($bx);
    return $obj;
}

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_);
    return unless $self;

    my $sequence_item = Genome::Reference->get(description => $self->name);
    if ($sequence_item) {
        my $db = $sequence_item->bfa_directory;
        if ($db) {
            $self->data_directory($db);
            return $self;
        } else {
            $self->delete;
            die('Failed to find bfa directory for genome reference '. $self->name);
        }
    }

    my $path = sprintf('%s/reference_sequences/%s','/gscmnt/839/info/medseq',$self->name);
    my $dna_type = $self->sample_type;
    $dna_type =~ tr/ /_/;
    my $dna_path = $path .'.'. $dna_type;
    if (-d $dna_path || -l $dna_path) {
        $path = $dna_path;
    }
    $self->data_directory($path);

    return $self;
}

sub full_consensus_path {
    my ($self,$format) = @_;
    $format ||= 'bfa';
    my $file = $self->data_directory . '/all_sequences.bfa';
    if ( -e $file){
        return $file;
    }
    $file = $self->data_directory . '/ALL.bfa';
    if ( -e $file){
        return $file;
    }
    return;
}

sub subreference_paths {
    my $self = shift;
    my %p = @_;

    my $ext = $p{reference_extension};

    return glob(sprintf("%s/*.%s",
                        $self->data_directory,
                        $ext));
}

sub subreference_names {
    my $self = shift;
    my %p = @_;

    my $ext = $p{reference_extension} || 'fasta';

    my @paths = $self->subreference_paths(reference_extension=>$ext);

    my @basenames = map {basename($_)} @paths;
    for (@basenames) {
        s/\.$ext$//;
    }

    return @basenames;
}

sub description {
    my $self = shift;
    my $path = $self->data_directory . '/description';
    unless (-e $path) {
        return 'all';
    }
    my $fh = IO::File->new($path);
    my $desc = $fh->getline;
    chomp $desc;
    return $desc;
}

1;

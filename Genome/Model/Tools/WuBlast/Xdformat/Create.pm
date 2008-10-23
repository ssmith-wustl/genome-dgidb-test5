package Genome::Model::Tools::WuBlast::Xdformat::Create;

use strict;
use warnings;

use Genome;

use File::Basename;

class Genome::Model::Tools::WuBlast::Xdformat::Create {
    is => 'Genome::Model::Tools::WuBlast::Xdformat',
    has => [
            database => {
                         is => 'String',
                         is_input => 1,
                         doc => 'the path to a new or existing database',
                     },
        ],
    has_many => [
            fasta_files => {
                            is => 'String',
                            is_input => 1,
                            doc => 'a list of paths to fasta sequence files',
                        },
             ],
};

sub help_brief {
    "a genome-model tool for creating a nucleotide wu-blastable database",
}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
gt wu-blast xdformat create --database --fasta-files
EOS
}

sub help_detail {
    return <<EOS
EOS
}

sub execute {
    my $self = shift;

    my ($basename,$dirname,$suffix) = File::Basename::fileparse($self->database);
    opendir(DIR,$dirname) ||
        die "Failed to open directory $dirname";
    my @files = grep { /\.x.*/ } readdir(DIR);
    closedir(DIR);
    if (@files) {
        $self->error_message('Database '. $self->database .' already exists with files '. join(',',@files));
        return;
    }

    my $cmd = 'xdformat -n -o '. $self->database .' '. join(' ',$self->fasta_files);
    $self->status_message('Running: '. $cmd);
    my $rv = system($cmd);
    unless ($rv == 0) {
        $self->error_message("non-zero return value($rv) from command '$cmd'");
        return;
    }
    return 1;
}

1;


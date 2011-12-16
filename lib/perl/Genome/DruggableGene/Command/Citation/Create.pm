package Genome::DruggableGene::Command::Citation::Create;

use strict;
use warnings;

use Genome;
use IO::File;

class Genome::DruggableGene::Command::Citation::Create {
    is => 'Genome::Command::Base',
    has_input => [
        source_db_name => { is => 'Text', doc => 'The name of the druggable gene source database' },
        source_db_version => { is => 'Text', doc => 'The version identifier of the druggable gene source database' },
        citation_file => { is => 'PATH', doc => 'The path to a file containing a formatted citation' },
    ],
};

sub help_brief {

}

sub help_synopsis {
    my $self = shift;
    return <<"EOS"
EOS
}

sub help_detail {
    return <<EOS 
EOS
}

sub execute {
    my $self = shift;
    my $source_db_name = $self->source_db_name;
    my $source_db_version = $self->source_db_version;
    my $citation_file = $self->citation_file;

    my $citation_text = $self->_load_citation($citation_file);
    my $citation = Genome::DruggableGene::Citation->create(source_db_name => $source_db_name, source_db_version => $source_db_version, citation => $citation_text);
    return $citation;
}

sub _load_citation {
   my $self = shift; 
   my $citation_file_path = shift;
   my $citation_fh = IO::File->new($citation_file_path, 'r');
   my $citation = '';
   while (my $line = <$citation_fh>){
        chomp $line;
        $citation .= $line;
        $citation .= "\n";
   }
   chomp $citation;
   return $citation;
}

1;

package Genome::Model::Tools::PhredPhrap::ScfToPhd;

use strict;
use warnings;
  
use Genome;

use Data::Dumper;
use Finishing::Assembly::Phd::Directory;
#use Finishing::Assembly::Phd::Exporter;
use IO::Dir;

class Genome::Model::Tools::PhredPhrap::ScfToPhd {
    is => 'Genome::Model::Tools::PhredPhrap',
    has => [
    scf_file => {
        is => 'String', #file_r
        doc => 'File of SCF',
        is_optional => 0,
    }, 
    chromat_dir => { 
        is => 'String', #dir_r
        doc => 'Directory where the SCFs are located',
        is_optional => 0,
    },
    phd_file => { 
        is => 'String', #file_w
        doc => 'File to write the most recent phd for each SCF',
        is_optional => 0,
    },
    phd_dir => {
        is => 'String', #dir_rw,
        doc => 'Directory to put PHDs.',
        is_optional => 0,
    },
    rmphd => {
        is => 'Boolean',
        doc => 'Remove all phds in phd_dir, then run phred on each SCF.',
        default => 'true',
    },
    recall => {
        is => 'Boolean',
        doc => 'Run phred on the SCF, naming it to a new version.',
        default => 1,
    },
    ],
};

sub help_brief {
    return 'Runs phred on SCFs to create PHDs.';
}

sub _phd_schema {
    my ($self, $schema) = @_;

    $self->{_phd_schema} = $schema if defined $schema;

    return $self->{_phd_schema};
}

sub execute {
    my $self = shift;

    $self->_phd_schema( Finishing::Assembly::Phd::Directory->connect($self->phd_dir) );

    if ( $self->remove_all_phds and 0) { #FIXME really wanna remove all, or just in file?
        my $dir = IO::Dir->new($self->phd_dir);
        while ( defined ($_ = $dir->read) ) {
            unlink $_ if $_ =~ /\.phd\.\d+/;
        }
    }
#print "\t\tstep 1, scf_file = " . $self->scf_file . "\n";
    my $scf_fh = IO::File->new('<' . $self->scf_file)
        or ($self->error_message('Could not open scf file: ' . $self->scf_file) and return);
    my $phd_fh = IO::File->new('>' . $self->phd_file)
        or ($self->error_message( sprintr('Can\'t open file (%s) for writing', $self->phd_file)) and return);
#print "\t\tstep 2, scf_fh = $scf_fh\n";

    while ( my $scf_name = $scf_fh->getline ) {
#print "in loop:  $scf_name\n";
        chomp $scf_name;

        my $phd_name;
        if ( $self->recall_phds ) {
            $phd_name = $self->_run_phred($scf_name);
        }
        else {
            $phd_name = $self->_phd_schema->latest_phd_name($scf_name);
            $phd_name = $self->_run_phred($scf_name) unless $phd_name; 
        }

        next unless $phd_name;

        $self->_check_and_add_read_type($scf_name);

        $phd_fh->print("$phd_name\n");
    }

    $scf_fh->close;
    $phd_fh->close;

    $self->_phd_schema->disconnect;

    ($self->error_message("No phds found") and return) unless -s $self->phd_file;

    return 1;
}

sub remove_all_phds
{
    #stub
    return 0;
}


sub recall_phds
{
    #stub
    return 1;
}

sub _run_phred {
    my ($self, $scf_name) = @_;
    
    my $scf_file = sprintf('%s/%s', $self->chromat_dir, $scf_name);
    $self->error_message("Can't find scf ($scf_file\[.gz\])")
        and return unless -s $scf_file or -s "$scf_file.gz";
    
    my $phd_name = $self->_phd_schema->next_phd_name($scf_name);
    my $phd_file = $self->_phd_schema->phd_file($phd_name);
    my $command = "phred $scf_file -nocall -p $phd_file";
    system "$command";

    unless ( -s $phd_file ) {
        # Retry w/ process_nomatch
        system "$command -process_nomatch";
    }

    $self->error_msg("Phred failed on $scf_file")
        and return unless -s $phd_file;

    return $phd_name;
}

sub _check_and_add_read_type {
    my ($self, $scf_name) = @_;

    my $phd = $self->_phd_schema->latest_phd($scf_name);
    return 1 if @{$phd->wr};
    
    system sprintf(
        'determineReadTypes.perl -PhdDir %s -justThisPhdFile %s',
        $self->phd_dir,
        $self->_phd_schema->latest_phd_file($scf_name),
    ); 

    return 1;
}

1;

=pod

=head1 Name

=head1 Synopsis

=head1 Methods

=head1 Disclaimer

 Copyright (C) 2006 Washington University Genome Sequencing Center

 This module is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY or the implied warranty of MERCHANTABILITY
 or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
 License for more details.

=head1 Author(s)

 Eddie Belter <ebelter@watson.wustl.edu>

=cut

#$HeadURL$
#$Id$

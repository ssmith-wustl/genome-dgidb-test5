package Genome::Model::Tools::AmpliconAssembly::PrepareData;

use strict;
use warnings;

use Genome;

use Data::Dumper 'Dumper';
require File::Copy;

class Genome::Model::Tools::AmpliconAssembly::PrepareData {
    is => 'Genome::Model::Tools::AmpliconAssembly',
};

#< Helps >#
sub help_detail {
    return <<EOS;
Using the sequencing center, sequencing platform and assembler, this command will determine the amplicons and prep them for assembly.  Currently, only supporting gsc sanger data assembled with phredphrap.
EOS
}

sub help_synopsis {
}

#< Command >#
sub sub_command_sort_position { 13; }

sub create {
    my $class = shift;

    my $self = $class->SUPER::create(@_)
        or return;

    unless ( $self->_get_prepare_data_method ) {
        $self->delete;
        return;
    }
    
    return $self;
}

sub _get_prepare_data_method {
    my $self = shift;

    my $method = sprintf(
        '_prepare_%s_data_for_%s',
        $self->amplicon_assembly->sequencing_platform,
        $self->amplicon_assembly->assembler,
    );

    unless ( $self->can($method) ) {
        $self->error_message( 
            sprintf(
                'Invalid sequencing center (%s) and assembler (%s) combination.', 
                $self->amplicon_assembly->sequencing_platform,
                $self->amplicon_assembly->assembler,
            ) 
        );
        return;
    }

    return $method;
}

sub execute {
    my $self = shift;

    my $amplicons = $self->amplicon_assembly->get_amplicons
        or return;
    
    my $method = $self->_get_prepare_data_method;

    for my $amplicon ( @$amplicons ) {
        $self->$method($amplicon);
    }

    return 1;
}

sub _prepare_sanger_data_for_phredphrap {
    my ($self, $amplicon) = @_;

    $amplicon->create_scfs_file
        or return;

    my $scf2phd = Genome::Model::Tools::PhredPhrap::ScfToPhd->create(
        chromat_dir => $self->amplicon_assembly->chromat_dir,
        phd_dir => $self->amplicon_assembly->phd_dir,
        phd_file => $amplicon->phds_file,
        scf_file => $amplicon->scfs_file,
    );
    unless ( $scf2phd ) {
        $self->error_message("Can't create scf to phd command");
        return;
    }
    unless ( $scf2phd->execute ) {
        $self->error_message("Can't execute scf to phd command");
        return;
    } 
    
    my $phd2fasta = Genome::Model::Tools::PhredPhrap::PhdToFasta->create(
        fasta_file => $amplicon->fasta_file,
        phd_dir => $self->amplicon_assembly->phd_dir,
        phd_file => $amplicon->phds_file,
    );
    unless ( $phd2fasta ) {
        $self->error_message("Can't create phd to fasta command");
        return;
    }
    unless ( $phd2fasta->execute ) {
        $self->error_message("Can't execute phd to fasta command");
        return;
    }
    
    # Create raw reads fasta and qual file
    my $reads_fasta = $amplicon->reads_fasta_file;
    unlink $reads_fasta if -e $reads_fasta;
    File::Copy::copy(
        $amplicon->fasta_file,
        $reads_fasta,
    );
    my $reads_qual = $amplicon->reads_qual_file;
    unlink $reads_qual if -e $reads_qual;
    File::Copy::copy(
        $amplicon->qual_file,
        $reads_qual,
    );
    
    return 1;
}

1;

#$HeadURL$
#$Id$

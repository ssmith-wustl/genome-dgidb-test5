package Genome::Model::Tools::Soap::Metrics;

use strict;
use warnings;

use Genome;

class Genome::Model::Tools::Soap::Metrics {
    is => 'Genome::Model::Tools::Soap::Base',
    has => [
	    assembly_directory => {
            is => 'Text',
            doc => 'Path to soap assembly',
        },
        first_tier => {
            is => 'Number',
            doc => 'First tier value',
            is_optional => 1,
        },
        second_tier => {
            is => 'Number',
            doc => 'Second tier value',
            is_optional => 1,
        },
        major_contig_length => {
            is => 'Number',
            is_optional => 1,
            default_value => 300,
            doc => 'Cutoff value for major contig length',
        },
        output_file => {
            is => 'Text',
            is_optional => 1,
            doc => 'Stats output file',
        },
    ],
};

sub help_brief {
    return 'Produce metrics for soap assemblies'
}

sub help_detail {
    return;
}

sub __errors__ {
    my $self = shift;

    my @errors = $self->SUPER::__errors__(@_);
    return @errors if @errors;

    if ( $self->assembly_directory ) {
        if ( not -d $self->assembly_directory ) {
            push @errors, UR::Object::Tag->create(
                type => 'invalid',
                properties => [qw/ assembly_directory /],
                desc => 'The assembly_directory is not a directory!',
            );
            return @errors;
        }
        if ( not defined $self->output_file ) {
            my $create_edit_dir = $self->create_edit_dir;
            return if not $create_edit_dir;
            $self->output_file( $self->_resolve_stats_file );
        }
    }
    elsif ( not $self->output_file ) { 
        push @errors, UR::Object::Tag->create(
            type => 'invalid',
            properties => [qw/ output_file /],
            desc => 'No output file given and no assembly_directory given to determine the output file!',
        );
    }

    return @errors;
}

sub execute {
    my $self = shift;
    $self->status_message('Soap metrics...');

    # resolve/create contigs file
    my $contigs_file = $self->_resolve_contigs_bases_file;
    if ( not -s $contigs_file ) {
        $self->status_message('Create contig bases file...');
        $contigs_file = $self->_create_contigs_file;
        return if not $contigs_file;
        $self->status_message('Create contig bases file...OK');
    }

    # tier values
    my ($t1, $t2);
    if ($self->first_tier and $self->second_tier) {
        $t1 = $self->first_tier;
        $t2 = $self->second_tier;
    }
    else {
        my $est_genome_size = -s $contigs_file;
        $t1 = int ($est_genome_size * 0.2);
        $t2 = int ($est_genome_size * 0.2);
    }
    $self->status_message('Tier one: 1 to '.$t1);
    $self->status_message('Tier two: '.$t1.' to '.($t1 + $t2));

    # metrics
    my $metrics = Genome::Model::Tools::Sx::Metrics::Assembly->create(
        major_contig_threshold => $self->major_contig_length,
        tier_one => $t1,
        tier_two => $t2,
    );

    # add reads files
    for my $fastq ( @{$self->assembly_input_fastq_files} ) {
        $self->status_message('Add reads file: '.$fastq);
        my $add_ok = $metrics->add_reads_file($fastq.':type=sanger');
        return if not $add_ok;
    }

    # add contigs file
    $self->status_message('Add contig file: '.$contigs_file);
    my $add_contigs_ok = $metrics->add_contigs_file($contigs_file.':type=fasta');
    return if not $add_contigs_ok;

    # transform metrics
    my $text = $metrics->transform_xml_to('txt');
    if ( not $text ) {
        $self->error_message('Failed to transform metrics to text!');
        return;
    }

    # write file
    my $output_file = $self->output_file;
    unlink $output_file if -e $output_file;
    $self->status_message('Write output file: '.$output_file);
    my $fh = eval{ Genome::Sys->open_file_for_writing($output_file); };
    if ( not $fh ) {
        $self->error_message('Failed to open metrics output file!');
        return;
    }
    $fh->print($text);
    $fh->close;

    $self->status_message('Soap metrics...OK');
    return 1;
}

sub _create_contigs_file {
    my $self = shift;

    my $temp_dir = Genome::Sys->create_temp_directory;
    my $contigs_file = $temp_dir.'/contigs.bases';
    my $ccf =  Genome::Model::Tools::Soap::CreateContigsBasesFile->create(
        assembly_directory => $self->assembly_directory, # will use gapfill then scafSeq
        min_contig_length => 1,
        output_file => $contigs_file,
    );
    if ( not $ccf )  {
        $self->error_message("Failed to create create contigs bases!");
        return;
    }
    if  ( not $ccf->execute ) {
        $self->error_message("Failed to execute create contigs bases!");
        return;
    }

    return $contigs_file;
}

1;


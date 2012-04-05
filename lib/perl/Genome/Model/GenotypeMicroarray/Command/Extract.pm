package Genome::Model::GenotypeMicroarray::Command::Extract;

use strict;
use warnings;

use Genome;

class Genome::Model::GenotypeMicroarray::Command::Extract {
    is => 'Command::V2',
    has_optional => [
        output => {
            is => 'Text',
            default_value => '-',
            doc => 'The output. Defaults to STDOUT.',
        },
        fields => {
            is => 'Text',
            is_many => 1,
            default_value => [qw/ chromosome position alleles /],
            valid_values => [qw/ chromosome position alleles id sample_id log_r_ratio gc_score cnv_value cnv_confidence allele1 allele2 /],
            doc => 'The fields to output in the genotype file.',
        },
        separator => {
            is => 'Text',
            default_value => 'tab',
            doc => 'Field separator of the output. Use "tab" for tab delineated.',
        },
        model => {
            is => 'Genome::Model',
            doc => 'The genotype model to work with. This will get the most recent succeeded build.',
        },
        build => {
            is => 'Genome::Model::Build',
            doc => 'The genotype build to use.',
        },
        filters => {
            is => 'Text',
            is_many => 1,
            doc => "Filter genotypes. Give name and parameters, if required. Filters:\n gc_scrore => filter by min gc score (Ex: gc_score:min=0.7)\n invalid_iscan_ids => list of invalid iscan snvs compiled by Nate",
        },
        _filters => { is_transient => 1 },
        _original_genotype_fh => { is_transient => 1 },
        _output_fh => { is_transient => 1 },
    ],
};

sub help_brief {
    return 'extract genotype data from a build';
}

sub help_detail {
    return <<HELP;
HELP
}

sub execute {
    my $self = shift;
    $self->status_message('Extract genotytpes from build...');

    my $build = $self->_resolve_build;
    return if not $build;

    my $filters = $self->_create_filters;
    return if not $filters;

    my $genotype_fh = $self->_open_oringinal_genotype_file;
    return if not $genotype_fh;

    my $output_fh = $self->_open_output;
    return if not $output_fh;

    my $ok = $self->_output_genotypes;
    return if not $ok;

    $self->status_message('Done');
    return 1;
}

sub _resolve_build {
    my $self = shift;

    if ( $self->build ) {
        return 1;
    }

    my $model = $self->model;
    if ( not $model ) {
        $self->error_message('No model or build given!');
        return;
    }

    my $last_succeeded_build = $model->last_succeeded_build;
    if ( not $last_succeeded_build ) {
        $self->error_message();
        return;
    }
    $self->build($last_succeeded_build);

    return 1;
}

sub _create_filters {
    my $self = shift;

    return 1 if not $self->filters;
    $self->status_message('Filters...');

    my @filters;
    for my $filter_string ( $self->filters ) {
        $self->status_message('Filter: '.$filter_string);
        my ($name, $config) = split(':', $filter_string, 2);
        my %params;
        %params = map { split('=') } split(':', $config) if $config;
        my $filter_class = 'Genome::Model::GenotypeMicroarray::Filter::By'.Genome::Utility::Text::string_to_camel_case($name);
        my $filter = $filter_class->create(%params);
        if ( not $filter ) {
            $self->error_message("Failed to create fitler for $filter_string");
            return;
        }
        push @filters, $filter;
    }
    $self->_filters(\@filters);

    $self->status_message('Filters...OK');
    return 1;
}

sub _open_oringinal_genotype_file {
    my $self = shift;
    $self->status_message('Open original genotype file...');

    my $original_genotype_file = $self->build->original_genotype_file_path;
    $self->status_message('Original genotype file: '.$original_genotype_file);
    if ( not -s $original_genotype_file ) {
        $self->error_message('Original genotype file does not exist!');
        return;
    }
    my $genotype_fh = eval{ Genome::Sys->open_file_for_reading($original_genotype_file); };
    if ( not $genotype_fh ) {
        $self->error_message("Failed to open original genotype file ($original_genotype_file): $@");
        return;
    }

    $self->_original_genotype_fh($genotype_fh);
    $self->status_message('Open original genotype file...OK');
    return 1;
}

sub _open_output {
    my $self = shift;

    $self->status_message('Open output file...');

    my $output = $self->output;
    unlink $output if -e $output;
    $self->status_message('Output file: '.$output);
    my $output_fh = eval{ Genome::Sys->open_file_for_writing($output); };
    if ( not $output_fh ) {
        $self->error_message("Failed to open output file ($output): $@");
        return;
    }

    $self->status_message('Open output file...OK');

    $self->_output_fh($output_fh);
    return 1;
}

sub _output_genotypes {
    my $self = shift;
    $self->status_message('Output genotypes...');

    my $genotype_fh = $self->_original_genotype_fh;
    my $header_line = $genotype_fh->getline;
    if ( not $header_line ) {
        $self->error_message('Failed to get header line for genotype file!');
        return;
    }
    chomp $header_line;
    my @headers = split(/\t/, $header_line);
    $self->status_message('Found headers in genotype file: '. join(', ', @headers));

    my $filters = $self->_filters;
    my $sep = ( $self->separator eq 'tab' ? "\t" : $self->separator );
    my @fields = $self->fields;
    my $output_fh = $self->_output_fh;
    my ($total, $pass) = (qw/ 0 0 /);
    $self->status_message('Filtering genotypes...');
    GENOTYPE: while ( my $line = $genotype_fh->getline ) {
        $total++;
        chomp $line;
        my %genotype;
        @genotype{@headers} = split(/\t/, $line);
        $genotype{id} = $genotype{snp_name};
        for my $filter ( @$filters ) {
            next GENOTYPE if not $filter->filter(\%genotype);
            #print $filter->class." => $line\n" and next GENOTYPE if not $filter->filter(\%genotype);
        }
        $genotype{alleles} = $genotype{allele1}.$genotype{allele2};
        $pass++;
        $output_fh->print( join($sep, map { defined $genotype{$_} ? $genotype{$_} : 'NA' } @fields)."\n" );
    }
    $output_fh->flush;

    $self->status_message("Wrote $pass of $total genotypes. Output genotypes...OK");
    return 1;
}

1;


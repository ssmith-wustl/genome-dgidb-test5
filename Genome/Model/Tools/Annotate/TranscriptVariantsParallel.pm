package Genome::Model::Tools::Annotate::TranscriptVariantsParallel;

use strict;
use warnings;

use Genome;
use IO::File;
use File::Temp;
use Genome::Utility::IO::SeparatedValueReader;
use Workflow;
use File::Basename;
use Cwd 'abs_path';

class Genome::Model::Tools::Annotate::TranscriptVariantsParallel{
    is => ['Workflow::Operation::Command','Genome::Model::Tools::Annotate::TranscriptVariants'],
    workflow => sub {
        my $workflow = Workflow::Operation->create(
            name => 'parallel transcript variants',
            operation_type => Workflow::OperationType::Command->get('Genome::Model::Tools::Annotate::TranscriptVariants')
        );
        $workflow->parallel_by('variant_file');
        return $workflow;
    },
    has => [
        split_by_chromosome => {
            is => 'Boolean',
            is_optional => 1,
            doc => 'enable this flag to split the variants file by chromosome (default behavior)',
        },
        split_by_number => {
            is => 'Number',
            is_optional => 1,
            doc => 'enable this flag to split the variant file by number',
        },  
        _output_file => {
            is => 'Text',
            is_optional => 1,
        },
        _variant_files => {
            is => 'File::Temp',
            is_many => 1,
            is_optional => 1,
        },
        _temp_dir => {
            is => 'Text',
            is_optional => 1,
        },
    ], 
};

sub pre_execute {
    my $self = shift;

    if ($self->output_file eq 'STDOUT') {
        $self->error_message("Must specify an output file\n") and die;
    }

    # Simple checks on command line args
    if (-s $self->output_file) {
        die "$self->output_file exists and has a size, exiting.\n";
    }
    $self->_output_file($self->output_file);

    unless (-s $self->variant_file) {
        die "$self->variant_file does not exist or has no size, exiting.\n";
    }

    # Make temp dir
    $self->_temp_dir(abs_path(dirname($self->output_file)) . "/annotation_temp_$$/");
    unless (-d $self->_temp_dir or mkdir ($self->_temp_dir)) {
        $self->error_message("Could not create temporary annotation directory at $self->_temp_dir\n
            Please specify an output file in a directory you have write permissions\n");
        die;
    }

    # Split up the input file
    my $inputFileHandler = IO::File->new($self->variant_file);
    my @splitFiles;

    # Split by line number
    if ($self->split_by_number and not $self->split_by_chromosome) {
        my $done = 0;
        until ($done == 1) {
            my $temp = File::Temp->new(DIR => $self->_temp_dir);
            #my $outputFileHandler = IO::File->new($temp);
            push @splitFiles, $temp;
            for (1..$self->split_by_number) {
                my $line = $inputFileHandler->getline;
                unless ($line) {
                    $done = 1;
                    last;
                }
                #$outputFileHandler->print($line);
                $temp->print($line);
            }
            #$outputFileHandler->close;
            $temp->close;
            $self->variant_file([map { $_->filename } @splitFiles]);
        }
        $inputFileHandler->close;
    }

    # Split file by chromosome
    else {
        my @variant_columns = $self->variant_attributes;
        push @variant_columns, split(/,/, $self->extra_columns) if $self->extra_columns;
        my $reader = Genome::Utility::IO::SeparatedValueReader->new (
            input => $self->variant_file,
            headers => \@variant_columns,
            separator => '\t',
            is_regex => 1,
        );

        my $currChrom = '';
        my $fh;
        while (my $line = $reader->next) {
            my $chrom = $line->{chromosome_name};
            if ($chrom ne $currChrom) {
                $currChrom = $chrom;
                $fh->close if $fh;
                $fh = File::Temp->new (DIR => $self->_temp_dir);
                push @splitFiles, $fh;
            }

            my @newline;
            foreach (@variant_columns) {
                push @newline, $line->{$_};
            }

            $splitFiles[-1]->print(join("\t", @newline)."\n");
        }
        $fh->close;
        $self->variant_file([map { $_->filename } @splitFiles]);
    }
    $self->_is_parallel(1);
    $self->no_headers(1);
    $self->_variant_files(\@splitFiles);
    return 1;
}

sub post_execute {
    my $self = shift;

    foreach my $error (@Workflow::Simple::ERROR) {
        print $error->error;
    }

    my @output_files;
    for (@{$self->output_file}){
        print "output file undefined\n" and next unless $_;
        print "output file $_ doesn't exist\n" and next unless -e $_;
        print "output file $_ has no size\n" unless -s $_;  #still want to unlink these later
        push @output_files, $_;
    }

    Genome::Utility::FileSystem->cat(
        input_files => \@output_files, 
        output_file => $self->_output_file,
    );

    for my $file (@{$self->variant_file},@output_files) {
        unless (unlink $file) {
            $self->error_message('Failed to remove file '. $file .":  $!");
            die($self->error_message);
        }
    }

    unless (rmdir ($self->_temp_dir)) {
        $self->status_message("Could not remove temporary annotation directory at $self->_temp_dir\n");
    }

    $self->output_file($self->_output_file);
    return 1;
}
1;


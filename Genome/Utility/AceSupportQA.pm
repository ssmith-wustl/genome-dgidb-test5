package Genome::Utility::AceSupportQA;

#:eclark 11/17/2009 Code review.

# Shouldn't inherit from UR::Object.  Also shouldn't implement help_brief or help_detail.  This isn't a command object.
# Overrides create() for no reason
# Hard coded path $RefDir
# sync_phd_time_stamps() does filesystem calls on a parameter without validating its format or checking to see if its defined

use strict;
use warnings;
use DBI;
use Genome;
use GSC::IO::Assembly::Ace;
use Bio::DB::Fasta;

class Genome::Utility::AceSupportQA {
    is => 'UR::Object',
    has => [
        ref_check => { 
            is => 'String', 
            is_optional => 1,
            default => 0, 
            doc => 'Whether or not to check the reference sequence, to be used only with amplicon assemblies dumped from the database' 
        },
        check_phd_time_stamps => { 
            is => 'String', 
            is_optional => 1,
            default => 0, 
            doc => 'Whether or not to check the phd time stamps, maybe not currently functional?' 
        },
        fix_invalid_files => { 
            is => 'String', 
            is_optional => 1,
            default => 0, 
            doc => 'Whether or not to attempt to fix invalid files' 
        },
        contig_count => {
            is => 'Number',
            is_optional => 1,
            doc => 'The number of contigs found in the ace file',
        }
    ],
};


sub help_brief {
    "Check an ace file to see if it looks good";
}
sub help_detail {
    return <<EOS 
EOS
}

sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
        
    return $self;
}

#Generate a refseq;
my $RefDir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
my $refdb = Bio::DB::Fasta->new($RefDir); #$refdb is the entire Hs_build36_mask1c 

sub ace_support_qa {
    my $self = shift;
    my $ace_file = shift; ##Give full path to ace file including ace file name

    unless (-s $ace_file) {
        $self->error_message("Ace file $ace_file does not exist");
        return;
    }
    
    #invalid_files will be a hash of trace names and file type that are broken.
    my ($invalid_files,$project) = $self->parse_ace_file($ace_file); ##QA the read dump, phred and poly files


    if ($self->ref_check) {
	my ($refcheck) = $self->check_ref($project);
	if (!$refcheck) {
	    $self->error_message("The reference sequence is invalid for $project and should be fixed prior to analysis");
	    return 0;
	}
    }
    if ($invalid_files) {
        $self->error_message("There are invalid files for $project that should be fixed prior to analysis");
        $self->error_message("Here is a list of reads for $project with either a broken chromat, phd, or poly file");
        
        foreach my $read (sort keys %{$invalid_files}) {
            $self->error_message($read . join("\t", sort keys %{$invalid_files->{$read}}));
        }

        return 0;
    }

    return 1;
}

sub check_ref {
    my $self = shift;
    my $assembly_name = shift;
    my $amplicon_tag = GSC::AssemblyProject->get_reference_tag(assembly_project_name => $assembly_name);

    unless($amplicon_tag){
        $self->error_message("no amplicon tag from GSC::AssemblyProject->get_reference_tag(assembly_project_name => $assembly_name)... can't check the reference sequence");
        return;
    }
    
    my $amplicon = $amplicon_tag->ref_id;
    my ($chromosome) = $amplicon_tag->sequence_item_name =~ /chrom([\S]+)\./;

    my $amplicon_sequence = $amplicon_tag->sequence_base_string;
    my $amplicon_offset = $amplicon_tag->begin_position;

    my $amplicon_begin = $amplicon_tag->begin_position;
    my $amplicon_end = $amplicon_tag->end_position;

    my $assembly_length = length($amplicon_sequence);
    my $strand = $amplicon_tag->strand;

    my ($start,$stop) = sort ($amplicon_begin,$amplicon_end);
    my $length = $stop - $start + 1;

    unless ($assembly_length == $length) { 
        $self->error_message("the assembly_length doesn\'t jive with the spread on the coordinates"); 
    }

    my $sequence = $self->get_ref_base($chromosome,$start,$stop); ##this will come reverse complemented if the $strand eq "-"
    if ($strand eq "-") {
        my $revseq = $self->reverse_complement_sequence ($sequence); 
        $sequence = $revseq;
    }
    unless ($sequence eq $amplicon_sequence) { 
        $self->error_message("$assembly_name reference sequence doesn't look good.");
        return 0;
    } 

    return 1;
}

sub get_ref_base {
    my $self = shift;
    my ($chr_name,$chr_start,$chr_stop) = @_;

    my $seq = $refdb->seq($chr_name, $chr_start => $chr_stop);
    $seq =~ s/([\S]+)/\U$1/;
    return $seq;
}

sub reverse_complement_sequence {
    my $self = shift;
    my $seq = shift;

    my $seq_1 = new Bio::Seq(-seq => $seq);
    my $revseq_1 = $seq_1->revcom();
    my $revseq = $revseq_1->seq;

    return $revseq;
}

sub parse_ace_file {
    my $self = shift;
    my $ace_file = shift;

    my $traces_fof;
    my @da = split(/\//,$ace_file);
    my $ace_name = pop(@da);

    my $edit_dir = join'/',@da;

    pop(@da);
    my $project_dir = join'/',@da;
    my $project = pop(@da);

    my $chromat_dir = "$project_dir/chromat_dir";
    my $phd_dir = "$project_dir/phd_dir";
    my $poly_dir = "$project_dir/poly_dir";

    my $ao = GSC::IO::Assembly::Ace->new(input_file => $ace_file);

    my $contig_count;
    for my $name (@{ $ao->get_contig_names }) {
        $contig_count++;
        my $contig = $ao->get_contig($name);
        foreach my $read_name (keys %{ $contig->reads }) {
            unless ($read_name =~ /(\S+\.c1)$/) {
                $traces_fof->{$read_name}=1;
            }
        }
    }

    $self->contig_count($contig_count);

    my ($invalid_files) = $self->check_traces_fof($edit_dir,$project_dir,$chromat_dir,$phd_dir,$poly_dir,$traces_fof,$ace_file);

    return ($invalid_files,$project);
}

sub check_traces_fof {
    my $self = shift;
    my ($edit_dir,$project_dir,$chromat_dir,$phd_dir,$poly_dir,$traces_fof,$ace_file) = @_;

    my ($no_trace_file,$no_phd_file,$no_poly_file,$empty_trace_file,$empty_poly_file,$empty_phd_file,$ncntrl_reads,$read_count,$repaired_file);
    my ($trace_files_needed,$phd_files_needed,$poly_files_needed);

    for my $read (sort keys %{$traces_fof}) {
        $read_count++;

        if ($read =~ /^n\-cntrl/) {$ncntrl_reads++;}

        my $trace = "$chromat_dir/$read.gz";

        unless (-s $trace) {
            if ($self->fix_invalid_files) {
                system qq(read_dump -scf-gz $read --output-dir=$chromat_dir);
            }
            if (-s $trace) {
                $repaired_file++;
            } elsif (-e $trace) {
                $empty_trace_file++;
                $trace_files_needed->{$read}=1;
            } else {
                $no_trace_file++;
                $trace_files_needed->{$read}=1;
            }
        }

        my $poly = "$poly_dir/$read.poly";

        unless (-s $poly) {
            if (-e $poly) {
                $empty_poly_file++;
                $poly_files_needed->{$read}=1;
            } else {
                $no_poly_file++;
                $poly_files_needed->{$read}=1;
            }
        }
        
        my $phd = "$phd_dir/$read.phd.1";

        unless (-s $phd) {
            if (-e $phd) {
                $empty_phd_file++;
                $phd_files_needed->{$read}=1;
            } else {
                $no_phd_file++;
                $phd_files_needed->{$read}=1;
            }
        }
    }

    my $invalid_files;

    unless ($read_count) { 
        die "There are no reads in the ace file to be analyzed\n"; 
    }

    $self->status_message("Reads for analysis ==> $read_count");


    if ($no_trace_file || $empty_trace_file) {

        $no_trace_file ||= 0;
        $empty_trace_file ||= 0;

        my $n = $no_trace_file + $empty_trace_file;
        $self->error_message("nonviable trace files ==> $n");
        foreach my $read (sort keys %{$trace_files_needed}) {
            if ($self->fix_invalid_files) {
                $self->error_message("attempted redump of $read failed");
            }
            $invalid_files->{$read}->{trace}=1;
        }
    }

    if ($no_poly_file || $empty_poly_file) {
        if ($no_poly_file eq $read_count) {
            $self->status_message("There are no poly files, they can be created in analysis"); # is this logic correct? FIXME
        } else {

            $no_poly_file ||= 0;
            $empty_poly_file ||= 0;

            my $n = $no_poly_file + $empty_poly_file;
            if ($self->fix_invalid_files) {
                $self->status_message("will run phred to produce $n disfunctional poly files");
            }
            for my $read (sort keys %{$poly_files_needed}) {
                if ($trace_files_needed->{$read}) {
                    if ($self->fix_invalid_files) {
                        $self->status_messaage("no attempt made to produce a poly file for $read as the trace file is missing");
                    }
                    $invalid_files->{$read}->{poly}=1;
                } else {
                    if ($self->fix_invalid_files) {
                        system qq(phred -dd $poly_dir $chromat_dir/$read.gz);
                    }
                    my $poly = "$poly_dir/$read.poly";

                    if (-s $poly) {
                        $repaired_file++;
                        $self->status_message("poly file for $read ok");
                    }
                    else {
                        if ($self->fix_invalid_files) {
                            $self->status_message("Failed to produce a poly file for $read");
                        }
                        $invalid_files->{$read}->{poly}=1;
                    }
                }
            }
        }
    }

    if ($no_phd_file || $empty_phd_file) {

        unless($no_phd_file) {$no_phd_file=0;}
        unless($empty_phd_file) {$empty_phd_file=0;}

        my $n = $no_phd_file + $empty_phd_file;

        if ($self->fix_invalid_files) {
            $self->status_message("will run phred to produce $n disfunctional phd files");
        }
        foreach my $read (sort keys %{$phd_files_needed}) {
            if ($trace_files_needed->{$read}) {
                if ($self->fix_invalid_files) {
                    $self->status_message("no attempt made to produce a phd file for $read as the trace file is missing");
                }
                $invalid_files->{$read}->{phd}=1;
            } else {
                my $phd = "$phd_dir/$read.phd.1";

                if (-s $phd) {
                    $repaired_file++;
                } else {
                    $invalid_files->{$read}->{phd}=1;
                }
            }
        }
    }


    ##sync_phd_time_stamps is not working correctly. It didn't change the time stamp in the ace file
    if ($self->check_phd_time_stamps) {
        if ($self->fix_invalid_files) {
            $self->status_message("will attempt to sync the phd file time stamps with the ace file");
            ($ace_file)=$self->sync_phd_time_stamps($ace_file);

            unless (-s $ace_file) {
                die "The synced ace file $ace_file doesnt exist or has zero size";
            }
        }
    }

    if ($ncntrl_reads) {
        $self->status_message("There were $ncntrl_reads n-cntrl reads");
    }

    return ($invalid_files);
}

sub sync_phd_time_stamps {   ## this isn't being used and it doesn't appear to do what it should
    my $self = shift;
    my $ace = shift;

    #addapted from ~kkyung/bin/fix_autojoin_DS_line.pl

    use IO::File;
    use Data::Dumper;

    system qq(cp $ace $ace.presync);
    open(NEWACE,">$ace.synced");

    my $fh = IO::File->new("<$ace") || die "Can not open $ace";

    my $ds = {};

    while (my $line = $fh->getline)
    {
        if ($line =~ /^DS\s/)
        {
            my ($version) = $line =~ /VERSION:\s+(\d+)/;
            my ($chromat) = $line =~ /CHROMAT_FILE:\s+(\S+)/;
            my ($phd_file) = $line =~ /PHD_FILE:\s+(\S+)/;
            my ($time) = $line =~ /TIME:\s+(\w+\s+\w+\s+\d+\s+\d+\:\d+\:\d+\s+\d+)/;
            my ($chem) = $line =~ /CHEM:\s+(\S+)/;
            my ($dye) = $line =~ /DYE:\s+(\S+)/;
            my ($template) = $line =~ /TEMPLATE:\s+(\S+)/;
            my ($direction) = $line =~ /DIRECTION:\s+(\S+)/;

            $ds->{chromat_file} = (defined $chromat) ? $chromat : 'unknown';
            $ds->{version} = (defined $version) ? $version : 'unknown';
            $ds->{phd_file} = (defined $phd_file) ? $phd_file : 'unknown';
            $ds->{time} = (defined $time) ? $time : 'unknown';
            $ds->{chem} = (defined $chem) ? $chem : 'unknown';
            $ds->{dye} = (defined $dye) ? $dye : 'unknown';
            $ds->{template} = (defined $template) ? $template : 'unknown';
            $ds->{direction} = (defined $direction) ? $direction : 'unknown';
            $ds->{is_454} = ($chromat =~ /\.sff\:/) ? 'yes' : 'no';

            my $ds_line = 'DS ';
            if ($chromat =~ /\.sff\:/)
            {
                $ds_line .= 'VERSION: '.$ds->{version}.' ' unless $ds->{version} eq 'unknown';
            }
            $ds_line .= 'CHROMAT_FILE: '.$ds->{chromat_file}.' ';
            $ds_line .= 'PHD_FILE: '.$ds->{phd_file}.' ' unless $ds->{phd_file} eq 'unknown';
            $ds_line .= 'TIME: '.$ds->{time}.' ';
            $ds_line .= 'CHEM: '.$ds->{chem}.' ' unless $ds->{chem} eq 'unknown';
            $ds_line .= 'DYE: '.$ds->{dye}.' ' unless $ds->{dye} eq 'unknown';
            $ds_line .= 'TEMPLATE: '.$ds->{template}.' ' unless $ds->{template} eq 'unknown';
            $ds_line .= 'DIRECTION: '.$ds->{direction}.' ' unless $ds->{direction} eq 'unknown';

            $ds_line =~ s/\s+$//;

            print NEWACE $ds_line."\n";

        }
        else
        {
            print NEWACE $line;
        }
    }
    $fh->close;
    close(NEWACE);

    system qq(cp $ace.synced $ace);
    return($ace);
}

1;

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
use Bio::Seq;
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



sub create {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
        
    return $self;
}

sub ace_support_qa {
    my $self = shift;
    my $ace_file = shift; ##Give full path to ace file including ace file name

    unless (-s $ace_file) {
        $self->error_message("Ace file $ace_file does not exist");
        return;
    }
    
    #invalid_files will be a hash of trace names and file type that are broken.
    my ($invalid_files,$project,$polyfile_count) = $self->parse_ace_file($ace_file); ##QA the read dump, phred and poly files


    if ($self->ref_check) {
	my ($refcheck) = $self->check_ref($project);
	if (!$refcheck) {
	    $self->error_message("The reference sequence is invalid for $project and should be fixed prior to analysis");
	    return 0;
	}
    }
    if ($invalid_files) {
	
	my (@scf,@phd,@poly);
	foreach my $read (sort keys %{$invalid_files}) {
	    foreach my $type (sort keys %{$invalid_files->{$read}}) {

		if ($type eq "trace") {
		    push(@scf,$read);
		}
		if ($type eq "poly") {
		    push(@poly,$read);
		}
		if ($type eq "phd") {
		    push(@phd,$read);
		}
	    }
	}
	my $total_invalid_files = @scf + @poly + @phd;

	unless ($polyfile_count->{bad}) {$polyfile_count->{bad}=0;}
	unless ($polyfile_count->{good}) {$polyfile_count->{good}=0;}

	if (($polyfile_count->{bad} + $polyfile_count->{good}) == $total_invalid_files) {
	    
	    return 1;
	    
	} else {
	    
	    $self->error_message("There are invalid files for $project that should be fixed prior to analysis");
	    $self->error_message("Here is a list of reads for $project with either a broken chromat, phd, or poly file");
	    
	    #push @sources , $e unless grep (/$e/, @sources);
	    my @incomplete_traces;
	    foreach my $read (sort keys %{$invalid_files}) {
		my @badtypes;
		unless ($polyfile_count->{good} == 0) {push@badtypes,"poly" if grep (/$read/, @poly);}
		push@badtypes,"phd" if grep (/$read/, @phd);
		push@badtypes,"scf" if grep (/$read/, @scf);
		
		my $bt = join ' ' , @badtypes;
		my $file = "file";
		if (@badtypes > 1) { $file = "files";}
		$self->error_message("$read had bad => $bt $file");
	    }
	    
	    return 0;
	}
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
    
    my $sequence = $self->get_ref_base($chromosome,$start,$stop); ##this will come reverse complemented if $start > $stop 
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

    #Generate a refseq;
    my $RefDir = "/gscmnt/sata180/info/medseq/biodb/shared/Hs_build36_mask1c/";
    my $refdb = Bio::DB::Fasta->new($RefDir); #$refdb is the entire Hs_build36_mask1c 

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

    unless ($project_dir && -d $project_dir) {
	$self->error_message("Could not find the project directory");
	return 0;
    }

    my $project = pop(@da);

    my $chromat_dir = "$project_dir/chromat_dir";
    my $phd_dir = "$project_dir/phd_dir";
    my $poly_dir = "$project_dir/poly_dir";
    
    if ($self->fix_invalid_files) {
	mkdir ($chromat_dir,0775) if (! -d $chromat_dir);
	mkdir ($phd_dir,0775) if (! -d $phd_dir);
	mkdir ($poly_dir,0775) if (! -d $poly_dir);
    }

    my $ao = GSC::IO::Assembly::Ace->new(input_file => $ace_file);

    my $contig_count;
    for my $name (@{ $ao->get_contig_names }) {
        $contig_count++;
        my $contig = $ao->get_contig($name);
        foreach my $read_name (keys %{ $contig->reads }) {
            unless ($read_name =~ /(\S+\.c1)$/ || $read_name eq $contig->name) {
                $traces_fof->{$read_name}=1;
            }
        }
    }

    $self->contig_count($contig_count);

    my ($invalid_files,$polyfile_count) = $self->check_traces_fof($edit_dir,$project_dir,$chromat_dir,$phd_dir,$poly_dir,$traces_fof,$ace_file);

    return ($invalid_files,$project,$polyfile_count);
}

sub check_traces_fof {
    my $self = shift;
    my ($edit_dir,$project_dir,$chromat_dir,$phd_dir,$poly_dir,$traces_fof,$ace_file) = @_;

    my ($no_trace_file,$no_phd_file,$no_poly_file,$empty_trace_file,$empty_poly_file,$empty_phd_file,$ncntrl_reads,$read_count,$repaired_file);
    my ($trace_files_needed,$phd_files_needed,$poly_files_needed);
    my $invalid_files;
    my $polyfile_count;
    for my $read (sort keys %{$traces_fof}) {
        $read_count++;

        if ($read =~ /^n\-cntrl/) {$ncntrl_reads++;}

        my $trace = "$chromat_dir/$read.gz";
	if ("$chromat_dir/$read" && -s "$chromat_dir/$read") {  $trace =  "$chromat_dir/$read"; }

        unless (-s $trace) {
	    #my ($consensus) = `grep "CO $read" $ace_file`;
	    #if ($consensus) { $read_count--; }
	    #next if $consensus;

            if ($self->fix_invalid_files) {
		$self->status_message("$read.gz is missing from the chromat_dir will run read_dump to recover it.");
                system qq(read_dump -scf-gz $read --output-dir=$chromat_dir);
            }
            if (-s $trace) {
                $repaired_file++;
		if ($self->fix_invalid_files) {$self->status_message("$read.gz recovered");}
            } elsif (-e $trace) {
                $empty_trace_file++;
                $trace_files_needed->{$read}=1;
		if ($self->fix_invalid_files) {$self->status_message("$read.gz is an empty file");}
		$invalid_files->{$read}->{trace}=1;
            } else {
                $no_trace_file++;
                $trace_files_needed->{$read}=1;
		if ($self->fix_invalid_files) {$self->status_message("read_dump failed for $read.gz");}
		$invalid_files->{$read}->{trace}=1;
            }
        }

        my $poly = "$poly_dir/$read.poly";
	
        if (-s $poly) {
	    $polyfile_count->{good}++;
	} else {
            if ($self->fix_invalid_files) {
		if (-s $trace) {
		    $self->status_message("will run phred to recover $poly");
		    system qq(phred -dd $poly_dir $chromat_dir/$read.gz);
		} else {
		    $invalid_files->{$read}->{poly}=1;
		    $invalid_files->{$read}->{trace}=1;
		    $self->status_message("no attempt made to produce a poly file for $read as the trace file is missing");
		}
	    }
	    if (-s $poly) {
		$repaired_file++;
		if ($self->fix_invalid_files) {$self->status_message("$poly recovered");}
		$polyfile_count->{good}++;
            } elsif (-e $poly) {
                $empty_poly_file++;
                $poly_files_needed->{$read}=1;
		if ($self->fix_invalid_files) {$self->status_message("$poly is an empty file");}
		$invalid_files->{$read}->{poly}=1;
		$polyfile_count->{bad}++;
            } else {
                $no_poly_file++;
                $poly_files_needed->{$read}=1;
		if ($self->fix_invalid_files) {$self->status_message("phred failed to produce a poly file for $read.gz");}
		$invalid_files->{$read}->{poly}=1;
		$polyfile_count->{bad}++;
            }
        }
        
        my $phd = "$phd_dir/$read.phd.1";
	my $phd_time_stamps;
        unless (-s $phd) {
            if ($self->fix_invalid_files) {
		if (-s $trace) {
		    $self->status_message("will run phred to recover $phd");
		    system qq(phred -pd $phd_dir $chromat_dir/$read.gz);
		} else {
		    $invalid_files->{$read}->{phd}=1;
		    $invalid_files->{$read}->{trace}=1;
		    $self->status_message("no attempt made to produce a phd file for $read as the trace file is missing");
		}
	    }
	    if (-s $phd) {

		if ($self->fix_invalid_files) {
		    $repaired_file++;
		    $self->status_message("$phd recovered");
		    #($phd_time_stamps) = &get_phd_time_stamp($phd);
		    $phd_time_stamps->{$read}->{phd}=$phd;
		} else {
		    $self->status_message("$phd errored initially");
		}
            } elsif (-e $phd) {
                $empty_phd_file++;
                $phd_files_needed->{$read}=1;
		if ($self->fix_invalid_files) {$self->status_message("$phd is an empty file");}
		$invalid_files->{$read}->{phd}=1;
            } else {
                $no_phd_file++;
                $phd_files_needed->{$read}=1;
		if ($self->fix_invalid_files) {$self->status_message("phred failed to produce a phd file for $read.gz");}
		$invalid_files->{$read}->{phd}=1;
            }
        }
	
	if ($self->fix_invalid_files && $phd_time_stamps) {
	    ($phd_time_stamps) = &get_phd_time_stamp($self,$ace_file,$phd_time_stamps);
	    foreach my $read (sort keys %{$phd_time_stamps}) {
		print qq(read ==> $read\n);
		my $fixed = $phd_time_stamps->{$read}->{fixed};
		unless ($fixed) {$invalid_files->{$read}->{phd}=1;}
	    }
	}
    }

    unless ($read_count) { 
        die "There are no reads in the ace file to be analyzed\n"; 
    }

    $self->status_message("Reads for analysis ==> $read_count");

    if ($no_trace_file || $empty_trace_file) {
        $no_trace_file ||= 0;
        $empty_trace_file ||= 0;
        my $n = $no_trace_file + $empty_trace_file;
        $self->error_message("nonviable trace files ==> $n");
    } 

    if ($no_phd_file || $empty_phd_file) {
        unless($no_phd_file) {$no_phd_file=0;}
        unless($empty_phd_file) {$empty_phd_file=0;}
        my $n = $no_phd_file + $empty_phd_file;
        if ($self->fix_invalid_files) {
            $self->status_message("phred failed to produce $n disfunctional phd files");
        }
    }
    
    if ($ncntrl_reads) {
        $self->status_message("There were $ncntrl_reads n-cntrl reads");
    }
    
    return ($invalid_files,$polyfile_count);
}

sub get_phd_time_stamp {
    
    my ($self,$ace_file,$phd_time_stamps) = @_;

    open(ACE,"$ace_file") || $self->status_message("$ace_file failed to open can not update the time stamp");
    while (<ACE>) {
	chomp;
	my $line = $_;

	next unless $line =~ /DS CHROMAT_FILE: (\S+) PHD_FILE: (\S+) (TIME:[\S\s]+)$/;
	
	my $read = $1;
	my $time = $3;
	
	next unless $phd_time_stamps->{$read};
	
	my $phd = $phd_time_stamps->{$read}->{phd};
	if ($phd) {
	    ($phd_time_stamps) = &sync_phd_time_stamps($self,$read,$phd,$time,$phd_time_stamps);
	} 
    }
    
    close (ACE);

    return ($phd_time_stamps);
}

sub sync_phd_time_stamps {
    my ($self,$read,$phd,$time,$phd_time_stamps) = @_;
    
    system qq(cp $phd $phd.presync);
    my $presync = "$phd.presync";
    unless ($presync && -e $presync) {$self->status_message("failed to cp $phd to $presync");}
    
    open(PHD,">$phd") || $self->status_message("$phd failed to open can not update the time stamp");;
    open(PRESYNC,$presync) || $self->status_message("$presync failed to open can not update the time stamp");
    while (<PRESYNC>) {
	chomp;
	my $line = $_;
	###TIME: Thu Dec 17 12:12:35 2009
	my $time_stamp;
	if ($line =~ /^(TIME:[\S\s]+)$/) {
	    print PHD qq($time\n);
	} else {
	    print PHD qq($line\n);
	}
    }
    close PHD;
    close PRESYNC;

    my $fixed = `grep "$time" $phd`;
    if ($fixed) {chomp $fixed; $phd_time_stamps->{$read}->{fixed}=1;$self->status_message("$phd synchronized")}

    return ($phd_time_stamps);

}

1;

package Genome::Model::Tools::Bed::Convert::Indel::PindelToBed;

use warnings;
use strict;

use Genome;
use Workflow;

class Genome::Model::Tools::Bed::Convert::Indel::PindelToBed {
    is => ['Genome::Model::Tools::Bed::Convert::Indel'],
    has => [
        reference_fasta => {
            is => 'String',
            default=> Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fa',
            doc => "The reference fasta file used to look up the reference sequence with samtools faidx. This is necessary because pindel will truncate long reference sequences.",
        },
    ],
    has_transient_optional => [
        _big_output_fh => {
            is => 'IO::File',
            doc => 'Filehandle for the output of large events',
        },
    ],
    has_param => [
        # Make workflow choose 64 bit blades, this is needed for samtools faidx
        lsf_resource => {
            default_value => 'rusage[mem=4000] select[type==LINUX64] span[hosts=1] -M 4000000',
        },
        lsf_queue => {
            default_value => 'long'
        }, 
    ],
};

sub help_brief {
    "Transforms a file from pindel output format to bed format";
}

sub help_synopsis {
    return <<"EOS"
gmt bed convert indel pindel-to-bam --input-file pindel.outfile --output-file pindel.adapted 
EOS
}

sub help_detail {                           
    return <<EOS 
Transforms a file from pindel output format to bed format
EOS
}

# FIXME need to check for 64 bit but this causes a loop between super and this
=cut 
sub execute {
    my $self = shift;
    $DB::single=1;
    # test architecture to make sure we can run (needed for samtools faidx)
    unless (`uname -a` =~ /x86_64/) { 
       $self->error_message("Must run on a 64 bit machine");
       die;
    }

    return $self->SUPER::execute(@_);
}
=cut

sub initialize_filehandles {
    my $self = shift;
    
    if($self->_big_output_fh) {
        return 1; #Already initialized
    }
    
    my $big_output = $self->output . ".big_deletions";
    
    eval {
        my $big_output_fh = Genome::Utility::FileSystem->open_file_for_writing($big_output);
        $self->_big_output_fh($big_output_fh);
    };
    
    if($@) {
        $self->error_message('Failed to open file. ' . $@);
        $self->close_filehandles;
        return;
    }

    return $self->SUPER::initialize_filehandles(@_);
}

sub close_filehandles {
    my $self = shift;

    # close big deletions fh
    my $big_output_fh = $self->_big_output_fh;
    close($big_output_fh) if $big_output_fh;

    return $self->SUPER::close_filehandles(@_);
}

sub process_source { 
    my $self = shift;
    $DB::single=1;
    my $input_fh = $self->_input_fh;
    my %events;
    my ($chrom,$pos,$size,$type);

    while(my $line = $input_fh->getline){
        my $normal_support=0;
        my $read = 0;
        if($line =~ m/^#+$/){
            my $call = $input_fh->getline;
if($call =~ m/^3/) { $DB::single=1; }
            my $reference = $input_fh->getline;
            my @call_fields = split /\s/, $call;
            my $type = $call_fields[1];
            my $size = $call_fields[2];   #12
            my $mod = ($call =~ m/BP_range/) ? 2: -1;
            #my $support = ($type eq "I") ? $call_fields[10+$mod] : $call_fields[12+$mod];
            my $support = $call_fields[12+$mod];
           
            for (1..$support){
                $line = $input_fh->getline;
                if($line =~ m/normal/) {
                    $normal_support=1;
                }
                $read=$line;
            }
            
            my @bed_line = $self->parse($call, $reference, $read);
            unless((@bed_line)&& scalar(@bed_line)==5){
                next;
            }
            my $type_and_size = $type."/".$size;
            $self->status_message( $type_and_size . "\t" . join(" ",@bed_line) . "\n");
            $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'bed'}=join(",",@bed_line);
            if($normal_support){
                $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'normal'}=$normal_support;
            }
        }
    }
            

=cut
    while(my $line = $input_fh->getline) {
        my $normal_support=0;
        my $read = 0;
        if($line =~ m/^#+$/) {
            my $call = $input_fh->getline;
            my $reference = $input_fh->getline;
            while($line = $input_fh->getline) {
                if($line =~ m/^#+$/) {
                    last;
                }
                else {
                    my (undef, undef, undef, undef, $type, undef) = split /\t/, $line;
                    if($type =~ m/normal/) {
                        $normal_support=1;
                    }
                    $read=$line;
                }
            }
            my @bed_line = $self->parse($call, $reference, $read);
            unless((@bed_line)&& scalar(@bed_line)==5){
                next;
            }
            my @call_fields = split /\w/, $call;
            my $type = $call_fields[1];
            my $size = $call_fields[2];
            my $support = $call_fields[-1];
            my $type_and_size = $type."/".$size;
            $self->status_message( $type_and_size . "\t" . join(" ",@bed_line) . "\n");
            $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'bed'}=join(",",@bed_line);
            if($normal_support){
                $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'normal'}=$normal_support;
            }
        }
    }
=cut


   
 
    for $chrom (sort {$a cmp $b} (keys(%events))){
        for $pos (sort{$a <=> $b} (keys( %{$events{$chrom}}))){
            for my $type_and_size (sort(keys( %{$events{$chrom}{$pos}}))){
                unless(exists($events{$chrom}{$pos}{$type_and_size}{'normal'})){
                    $self->write_bed_line(split ",", $events{$chrom}{$pos}{$type_and_size}{'bed'});
                }
            }
        }
    }


#    while(my $line = $input_fh->getline) {
#        next unless($line =~ m/^#+$/);
#        my $call = $input_fh->getline;
#        my $reference = $input_fh->getline;
#        my $first_read = $input_fh->getline;
#        
#        my @bed_line = $self->parse($call, $reference, $first_read);
#        unless((@bed_line)&& scalar(@bed_line)==5){
#            next;
#        }
#        $self->write_bed_line(@bed_line);
#    }

    return 1;
}

sub parse {
    my $self=shift;
    #my $reference_fasta = $self->refseq;
    my ($call, $reference, $first_read) = @_;
    #parse out call bullshit
    chomp $call;
    my @call_fields = split /\s+/, $call;
    my $type = $call_fields[1];
    my $size = $call_fields[2];
    #my $chr = ($type eq "I") ? $call_fields[4] : $call_fields[6];
    #my $start= ($type eq "I") ? $call_fields[6] : $call_fields[8];
    #my $stop = ($type eq "I") ? $call_fields[7] : $call_fields[9];
    my $chr = $call_fields[6];
    my $start= $call_fields[8];
    my $stop = $call_fields[9];
    my $support = $call_fields[-1];
    my ($ref, $var);
    if($type =~ m/D/) {
        $var =0;
        ###Make pindels coordinates(which seem to be last undeleted base and first undeleted base) 
        ###conform to our annotators requirements

        ###also deletions which don't contain their full sequence should be dumped to separate file
       $stop = $stop - 1;
        my $allele_string;
        my $start_for_faidx = $start+1; 
        my $sam_default = Genome::Model::Tools::Sam->path_for_samtools_version;
        my $faidx_cmd = "$sam_default faidx " . $self->reference_fasta . " $chr:$start_for_faidx-$stop"; 
        my @faidx_return= `$faidx_cmd`;
        shift(@faidx_return);
        chomp @faidx_return;
        $allele_string = join("",@faidx_return);

        $ref = $allele_string;
    }
    elsif($type =~ m/I/) {
        $start = $start - 1;
        $ref=0;
        my ($letters_until_space) =   ($reference =~ m/^([ACGTN]+) /);
        my $offset_into_first_read = length($letters_until_space);
        $var = substr($first_read, $offset_into_first_read, $size);
    }
    if($size >= 100) {
        my $big_fh = $self->_big_output_fh;
        $big_fh->print("$chr\t$start\t$stop\t$size\t$support\n");
        return undef;
    }
    return ($chr,$start,$stop,$ref,$var);
}


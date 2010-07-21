package Genome::InstrumentData::AlignmentResult::RtgMapX;

use strict;
use warnings;
use File::Basename;
use File::Path;
use Genome;

class Genome::InstrumentData::AlignmentResult::RtgMapX{
    is => 'Genome::InstrumentData::AlignmentResult',
    
    has_constant => [
        aligner_name => { value => 'rtg map x', is_param=>1 },
    ],
    has => [
        _max_read_id_seen => { default_value => 0, is_optional => 1},
        _file_input_option =>   { default_value => 'fastq', is_optional => 1},
    ]
};

sub required_arch_os { 'x86_64' }

sub required_rusage { 
    "-R 'select[model!=Opteron250 && type==LINUX64 && tmp>90000 && mem>40000] span[hosts=1] rusage[tmp=90000, mem=40000]' -M 40000000 -n 4";
}

sub _decomposed_aligner_params {
    my $self = shift;

    #   -U produce unmapped sam
    #   -Z do not zip sam
    my $aligner_params = ($self->aligner_params || '') . " -U -Z -T 4"; #append core & space
    
    return ('rtg_aligner_params' => $aligner_params);
}

sub _run_aligner {
    my $self = shift;
    my @input_pathnames = @_;

    if (@input_pathnames == 1) {
        $self->status_message("_run_aligner called in single-ended mode.");
    } elsif (@input_pathnames == 2) {
        $self->status_message("_run_aligner called in paired-end mode.");
    } else {
        $self->error_message("_run_aligner called with " . scalar @input_pathnames . " files.  It should only get 1 or 2!");
        die $self->error_message;
    }


    # get refseq info
    my $reference_build = $self->reference_build;
    
    my $reference_sdf_path = $reference_build->full_consensus_path('sdf'); 
    
    # Check the local cache on the blade for the fasta if it exists.
    if (-e "/opt/fscache/" . $reference_sdf_path) {
        $reference_sdf_path = "/opt/fscache/" . $reference_sdf_path;
    }

    my $sam_file = $self->temp_scratch_directory . "/all_sequences.sam";
    my $sam_file_fh = IO::File->new(">>" . $sam_file );
    my $unaligned_file = $self->temp_scratch_directory . "/unaligned.txt";
    my $unaligned_file_fh = IO::File->new(">>" . $unaligned_file); 

    foreach my $input_pathname (@input_pathnames)
    {
        my $scratch_directory = $self->temp_scratch_directory;
        my $staging_directory = $self->temp_staging_directory;

        #   To run RTG, have to first convert ref and inputs to sdf, with 'rtg format', 
        #   for which you have to designate a destination directory

        #STEP 1 - convert input to sdf
        my $input_sdf = File::Temp::tempnam($scratch_directory, "input-XXX") . ".sdf"; #destination of converted input
        my $output_dir = File::Temp::tempnam($scratch_directory, "output-XXX") . ".sdf";  
        my %output_files = (aligned_file =>"$output_dir/alignments.txt", unaligned_file => "$output_dir/unmapped.txt"); 
        my $rtg_fmt = Genome::Model::Tools::Rtg->path_for_rtg_format($self->aligner_version);
        my $cmd;

        $cmd = sprintf('%s --format=%s -o %s %s',
                $rtg_fmt,
                $self->_file_input_option,
                $input_sdf,
                $input_pathname);  

        Genome::Utility::FileSystem->shellcmd(
                cmd                 => $cmd, 
                input_files         => [$input_pathname],
                output_directories  => [$input_sdf],
                skip_if_output_is_present => 0,
                );

        #check sdf output was created
        $DB::single=1;
        my @idx_files = glob("$input_sdf/*");
        if (!@idx_files > 0) {
            die("rtg formatting of [$input_pathname] failed  with $cmd");
        }

        #STEP 2 - run rtg mapx aligner  
        my %aligner_params = $self->_decomposed_aligner_params;
        my $rtg_mapx = Genome::Model::Tools::Rtg->path_for_rtg_mapx($self->aligner_version);
        my $rtg_aligner_params = (defined $aligner_params{'rtg_aligner_params'} ? $aligner_params{'rtg_aligner_params'} : "");
        $cmd = sprintf('%s -t %s -i %s -o %s %s', 
                $rtg_mapx,
                $reference_sdf_path,
                $input_sdf,
                $output_dir,
                $rtg_aligner_params);

        Genome::Utility::FileSystem->shellcmd(
                cmd          => $cmd,
                input_files  => [ $reference_sdf_path, $input_sdf ],
                output_files => [values (%output_files), "$output_dir/done"],
                skip_if_output_is_present => 0,
                );

        #STEP 3.1 - append mapped to all_sequences

        #########################################
        #                                       #
        #   rtg mapx produces alignment.txt,    #
        #   with the following columns:         #
        #                                       #
        #   0:    template-name	                #
        #   1:    frame	                        #
        #   2:    read-id	                #
        #   3:    template-start	        #
        #   4:    template-end                  #	
        #   5:    template-length	        #
        #   6:    read-start	                #
        #   7:    read-end	                #
        #   8:    read-length	                #
        #   9:    template-protein	        #
        #  10:    read-protein	                #
        #  11:    alignment	                #
        #  12:    identical	                #
        #  13:    %identical                    #	
        #  14:    positive	                #
        #  15:    %positive	                #
        #  16:    mismatches	                #
        #  17:    raw-score	                #
        #  18:    bit-score	                #
        #  19:    e-score                       #
        #                                       #        
        #########################################

        #STEP 3.0 rename reads
        my $rr_file = "$output_dir/rr.txt";
        $cmd = sprintf('rtg mapxrename -i %s -o %s %s', 
                        $input_sdf, 
                        $rr_file,
                        $output_files{aligned_file},);
        
        Genome::Utility::FileSystem->shellcmd(
            cmd             =>  $cmd,
            input_files     =>  [$input_sdf, $output_files{aligned_file}],
            output_files    =>  [$rr_file],
            skip_if_output_is_present => 0,
        );
        unless (-s $rr_file) {
            die "The mapx output file $rr_file is zero length; something went wrong.";
        }

        my $rtg_fh = IO::File->new( $rr_file );    
        my $previous_max_id = $self->_max_read_id_seen; 
        my $max_id_seen;

        while (<$rtg_fh>) 
        {
            chomp;
            next if $_=~/^#/; #eat header line

            my @rtg_columns = split("\t", $_);
            my @sam_columns;

            my ($template_protein, $read_protein, $alignment) = (uc($rtg_columns[9]), uc($rtg_columns[10]), uc($rtg_columns[11])); #ensure capitalization for sync'ing with samtools

                push(@sam_columns, $rtg_columns[2]);                                                    # QNAME from read-id
                push(@sam_columns, int($rtg_columns[1]) > 0 ? 16 : 0);                                  # FLAG from frame > 0 ? 16 : 0
                push(@sam_columns, $rtg_columns[0]);                                                    # RNAME from template-name 
                push(@sam_columns, $rtg_columns[3]);                                                    # POS from template-start
                push(@sam_columns, 255);                                                                # MAPQ faked 
                push(@sam_columns, $self->_create_cigar($rtg_columns[11]));                             # CIGAR from parsing alignment 
                push(@sam_columns, "=");                                                                # MRNM from RNAME 
                push(@sam_columns, 0);                                                                  # MPOS faked 
                push(@sam_columns, 0);                                                                  # ISIZE faked
                push(@sam_columns, $read_protein);                                                      # SEQ from (%identical = 100 ? "=" : read-protein) 
                push(@sam_columns, "*");                                                                # QUAL faked
                push(@sam_columns, "NM:i:" . $rtg_columns[16]);                                         # TAG{NM:i} from mismatches 
                push(@sam_columns, "MD:Z:" . $self->_create_mdz($rtg_columns[9], $rtg_columns[11]));    # TAG{MD:Z} from template-protein and alignment 
                push(@sam_columns, "FR:i:" . $rtg_columns[1]);                                          # TAG{FR:i} from frame
                push(@sam_columns, "TE:i:" . $rtg_columns[4]);                                          # TAG{TE:i} from template-end 
                push(@sam_columns, "TL:i:" . $rtg_columns[5]);                                          # TAG{TL:i} from template-length 
                push(@sam_columns, "RS:i:" . $rtg_columns[6]);                                          # TAG{TS:i} from read-start 
                push(@sam_columns, "RE:i:" . $rtg_columns[7]);                                          # TAG{TL:i} from read-end
                push(@sam_columns, "RL:i:" . $rtg_columns[8]);                                          # TAG{TL:i} from read-length 
                push(@sam_columns, "TP:Z:" . $template_protein);                                        # TAG{TP:Z} from template-protein 
                push(@sam_columns, "RP:Z:" . $read_protein);                                            # TAG{RP:Z} from read-protein
                push(@sam_columns, "AL:Z:" . $alignment);                                               # TAG{AL:Z} from alignment
                push(@sam_columns, "ID:i:" . $rtg_columns[12]);                                         # TAG{ID:i} from identical 
                push(@sam_columns, "IP:i:" . $rtg_columns[13]);                                         # TAG{IP:i} from %identical 
                push(@sam_columns, "PO:i:" . $rtg_columns[14]);                                         # TAG{PO:i} from positive 
                push(@sam_columns, "PP:i:" . $rtg_columns[15]);                                         # TAG{PP:i} from %positive
                push(@sam_columns, "SC:i:" . $rtg_columns[17]);                                         # TAG{SC:i} from raw-score 
                push(@sam_columns, "BS:f:" . $rtg_columns[18]);                                         # TAG{BS:f} from bit-score 
                push(@sam_columns, "EV:f:" . $rtg_columns[19]);                                         # TAG{EV:f} from e-score 

            #track max id 
            if ($sam_columns[0] > $max_id_seen) {
                    $max_id_seen = $sam_columns[0];
            }
            # are we in a subsequent pass of alignment and need to offset read ids?
            if ($previous_max_id != 0) {
                $sam_columns[0] += $previous_max_id;
            }

            $sam_file_fh->print( join("\t", @sam_columns) . "\n" );
        }

        $rtg_fh->close;
        $sam_file_fh->close;

        # confirm that at the end we have a nonzero sam file, this is what'll get turned into a bam and copied out.
        unless (-s $sam_file) {
            die "The sam output file $sam_file is zero length; something went wrong.";
        }

        #STEP 4 - append unaligned file - rtg mapx produces a file unaligned.txt with only read-ids.  Can't use for sam, so just append the id's to a separate file
        my $rtg_unaligned_fh = IO::File->new ($output_files{unaligned_file});

        while (<$rtg_unaligned_fh>)
        {
            ###############################
            #   columns for unaligned.txt # 
            #   0:  read-id               #  
            #   1:  reason-unmapped       #
            ###############################

            next if $_=~/^#/; #eat header line

                my ($read_id) = split("\t", $_); #get first column val

            #track max id 
            if ($read_id > $max_id_seen) {
                    $max_id_seen = $read_id;
            }
            # are we in a subsequent pass of alignment and need to offset read ids?
            if ($previous_max_id != 0) {
                $read_id += $previous_max_id;
            }

            $unaligned_file_fh->print("$read_id\n");
        }   
        $rtg_unaligned_fh->close;
        $unaligned_file_fh->close;

        # save back the max id for the next pass
        $self->_max_read_id_seen($max_id_seen);

        # STEP 5 - copy log files 
        my $log_input = "$output_dir/mapx.log";
        my $log_output = $self->temp_staging_directory . "/rtg_mapx.log";
        $cmd = sprintf('cat %s >> %s', $log_input, $log_output);   

        Genome::Utility::FileSystem->shellcmd(
                cmd          => $cmd,
                input_files  => [ $log_input ],
                output_files => [ $log_output ],
                );

    } 
    return 1;
}

sub aligner_params_for_sam_header {
    my $self = shift;
    my $cmd = Genome::Model::Tools::Rtg->path_for_rtg_mapx($self->aligner_version);
    my %params = $self->_decomposed_aligner_params;
    my $aln_params = $params{rtg_aligner_params};
    
    return "$cmd $aln_params"; 
}

sub _create_cigar
{
    #produce "CIGAR string" from protein alignment

    my ($self,$str) = @_;
    my $cigar = '';

    while($str)
    {
        if ($str=~m/(^\S+)(.*$)/)
        {
            $cigar .= length($1) . "M";
            $str=$2;
        }
        elsif($str=~m/(^\s+)(.*$)/)
        {
            $cigar .= length($1) . "I";
            $str=$2;
        }
        else
        {
           last;
        }
    }
    return $cigar;
}

sub _create_mdz
{
    #produce value for MD:Z tag (match count | mismatching letters)

    my ($self, $template, $aln)= @_;
    my $mdz = '';

    if (length($template) == length($aln)) #strings need to be equal for this to work
    {
        my ($match_count, $mismatch_count);

        while ($aln)
        {
            if ($aln=~m/(^\S+)(.*$)/)
            {
                $match_count = length($1);
                $mdz .= $match_count;
                $aln=$2;
                $template = substr($template, $match_count);
            }
            elsif($aln=~m/(^\s+)(.*$)/)
            {
                $mismatch_count = length($1);
                $mdz .= substr($template, 0, $mismatch_count); 
                $aln=$2;
                $template = substr($template, $mismatch_count);
            }
            else
            {
                last;
            }
        }
    }
    return $mdz; 
}

sub fillmd_for_sam
{
    return 1;
}

=pod
sub sam_to_rtg
{
    for reconstructing rtg output from sam created by rtg_to_sam
    
    ################################################
    #   sam format                                 #             
    #                                              # 
    #   0  <QNAME>      10 <QUAL>       20  <RP:Z> # 
    #   1  <FLAG>       11  <NM:i>      21  <AL:Z> #       
    #   2  <RNAME>      12  <MD:Z>      22  <ID:i> # 
    #   3  <POS>        13  <FR:i>      23  <IP:i> # 
    #   4  <MAPQ>       14  <TE:i>      24  <PO:i> # 
    #   5  <CIGAR>      15  <TL:i>      25  <PP:i> # 
    #   6  <MRNM>       16  <RS:i>      26  <SC:i> #  
    #   7  <MPOS>       17  <RE:i>      27  <BS:f> #  
    #   8  <ISIZE>      18  <RL:i>      28  <EV:f> # 
    #   9  <SEQ>        19  <TP:Z>                 # 
    ################################################

    my ($self,$file) = @_; 
    my $file_to_parse_fh = IO::File->new( $file );
    my $body;

    while (<$file_to_parse_fh>)
    {
        chomp;
        next if !$_ or $_=~/^@/; #eat nulls & header

        my @sam_columns = split("\t", $_);
        my @rtg_columns;

        push(@rtg_columns, $sam_columns[2]);                                                    # template-name from RNAME
        push(@rtg_columns, _strip_tag($sam_columns[13]));                                       # frame from TAG{FR:i} 
        push(@rtg_columns, $sam_columns[0]);                                                    # read-id from QNAME 
        push(@rtg_columns, $sam_columns[3]);                                                    # template-start from POS 
        push(@rtg_columns, _strip_tag($sam_columns[14]));                                       # template-end from TAG{TE:i}
        push(@rtg_columns, _strip_tag($sam_columns[15]));                                       # template-length from TAG{TL:i}
        push(@rtg_columns, _strip_tag($sam_columns[16]));                                       # read-start from TAG{RS:i} 
        push(@rtg_columns, _strip_tag($sam_columns[17]));                                       # read-end from TAG{RE:i}
        push(@rtg_columns, _strip_tag($sam_columns[18]));                                       # read-length from TAG{RL:i}
        push(@rtg_columns, _strip_tag($sam_columns[19]));                                       # template-protein from TAG{TP:Z}
        push(@rtg_columns, _strip_tag($sam_columns[20]));                                       # read-protein from TAG{RP:Z} 
        push(@rtg_columns, _strip_tag($sam_columns[21]));                                       # alignment	from TAG{AL:Z}
        push(@rtg_columns, _strip_tag($sam_columns[22]));                                       # identical	from TAG{ID:i}
        push(@rtg_columns, _strip_tag($sam_columns[23]));                                       # %identical from TAG{IP:i}
        push(@rtg_columns, _strip_tag($sam_columns[24]));                                       # positive from TAG{PO:i}
        push(@rtg_columns, _strip_tag($sam_columns[25]));                                       # %positive from TAG{PP:i}	
        push(@rtg_columns, _strip_tag($sam_columns[11]));                                       # mismatches from TAG{NM:i}
        push(@rtg_columns, _strip_tag($sam_columns[26]));                                       # raw-score	from TAG{SC:i}
        push(@rtg_columns, _strip_tag($sam_columns[27]));                                       # bit-score from TAG{BS:f}
        push(@rtg_columns, _strip_tag($sam_columns[28]));                                       # e-score from TAG{EV:f}

        $body .= join("\t", @rtg_columns) . "\n";
    }

    print "#"  . join("\t", ('template-name', 'frame', 'read-id', 'template-start', 'template-end', 'template-length', 'read-start', 'read-end', 'read-length', 'template-protein', 'read-protein', 'alignment', 'identical', '%identical',  'positive', '%positive', 'mismatches', 'raw-score', 'bit-score', 'e-score')) . "\n";

    print "$body";

    $file_to_parse_fh->close;
}

sub _strip_tag
{
    my $str = shift;
    $str=~/(.+:)(.*)/;
    return $2;
}



sub _compute_alignment_metrics 
{
    return;
}
=cut


#extract reads from a set of bams in breakdancer predicted regions
package Genome::Model::Tools::Sv::AssemblyValidation;


use strict;
use warnings;
use Genome;
use Bio::SeqIO;
use File::Temp;
use File::Slurp;

=cut
my %opts = (l=>500,p=>1000,s=>0,q=>0,n=>0,m=>10,x=>3,P=>-10,G=>-10,S=>0.02,A=>500,Q=>0);
getopts('l:d:c:p:r:s:Q:q:t:n:a:b:f:km:MRzv:hD:x:i:P:G:I:A:S:L:',\%opts);
die("
Usage:   AssemblyValidation.pl <SV file, default in BreakDancer format> <bam files ... >
Options:
         -d DIR     Directory where all intermediate files are saved
         -I DIR     Read intermediate files from DIR instead of creating them
         -f FILE    Save Breakpoint sequences in file
         -r FILE    Save relevant cross_match alignment results to file
         -z         Customized SV format, interpret column from header that must start with # and contain chr1, start, chr2, end, type, size
         -v FILE    Save unconfirmed predictions in FILE
         -h         Make homo variants het by adding same amount of randomly selected wiletype reads
         -l INT     Flanking size [$opts{l}]
         -A INT     Esimated maximal insert size [$opts{A}]
         -q INT     Only assemble reads with mapping quality > [$opts{q}]
         -m INT     Minimal size (bp) for an assembled SV to be called confirmed [$opts{m}]
         -i INT     invalidate indels are -i bp bigger or smaller than the predicted size, usually 1 std insert size
         -a INT     Get reads with start position bp into the left breakpoint, default [50,100,150]
         -b INT     Get reads with start position bp into the right breakpoint, default [50,100,150]
         -S FLOAT   Maximally allowed polymorphism rate in the flanking region [$opts{S}];
         -P INT     Substitution penalty in cross_match alignment [$opts{P}]
         -G INT     Gap Initialization penalty in cross_match alignment [$opts{G}]
         -M         Prefix reference name with \'chr\' when fetching reads using samtools view
         -R         Assemble Mouse calls, NCBI reference build 37

Filtering:
         -p INT     Ignore cases that have average read depth greater than [$opts{p}]
         -c STRING  Specify a single chromosome
         -s INT     Minimal size of the region to analysis [$opts{s}]
         -Q INT     minimal BreakDancer score required for analysis [$opts{Q}]
         -t STRING  type of SV
         -n INT     minimal number of supporting reads [$opts{n}]
         -L STRING  Ingore calls supported by libraries that contains (comma separated) STRING
         -k         Attach assembly results as additional columns in the input file
         -D DIR     A directory that contains a set of supplementary reads (when they are missing from the main data stream)
         -x INT     Duplicate supplementary reads [$opts{x}] times
\n") unless ($#ARGV>=1);
=cut


class Genome::Model::Tools::Sv::AssemblyValidation {
    is  => 'Genome::Model::Tools::Sv',
    has => [
        sv_file => {
            type => 'String',
            doc  => 'input SV file, default in BreakDancer format',
        },
        bam_files => {
            type => 'String',
            doc  => 'bam files, comma separated',
        },
        output_file  => {
            type => 'String',
            doc  => 'output file of assembly validation',
        },
    ],
    has_optional => [
        intermediate_save_dir => {
            type => 'String',
            doc  => 'Directory where all intermediate files are saved',
        },
        intermediate_read_dir => {
            type => 'String',
            doc  => 'Read intermediate files from DIR instead of creating them',
        },
        breakpoint_seq_file => {
            type => 'String',
            doc  => 'Save Breakpoint sequences in file',
        },
        cm_aln_file => {
            type => 'String',
            doc  => 'Save relevant cross_match alignment results to file',
        },
        custom_sv_format => {
            type => 'Boolean',
            doc  => 'Customized SV format, interpret column from header that must start with # and contain chr1, start, chr2, end, type, size',
        },
        unconfirm_predict_file => {
            type => 'String',
            doc  => 'Save unconfirmed predictions in file',
        },,
        homo_var_het => {
            type => 'Boolean',
            doc  => 'Make homo variants het by adding same amount of randomly selected wiletype reads',
        },
        flank_size => {
            type => 'Integer',
            doc  => 'Flanking size',
            default_value => 500,
        },
        est_max_ins_size => {
            type => 'Integer',
            doc  => 'Esimated maximal insert size',
            default_value => 500,
        },
        map_qual_to_asm => {
            type => 'Integer',
            doc  => 'Only assemble reads with mapping quality >',
            default_value => 0,
        },
        min_size_of_confirm_asm_sv => {
            type => 'Integer',
            doc  => 'Minimal size (bp) for an assembled SV to be called confirmed',
            default_value => 10,
        },
        invalid_indel_range => {
            type => 'Integer',
            doc  => 'invalidate indels are -i bp bigger or smaller than the predicted size, usually 1 std insert size',
        },
        start_pos_to_left_breakpoint => {
            type => 'String',
            doc  => 'Get reads with start position bp into the left breakpoint, comma separated, default [50,100,150]',
        },
        start_pos_to_right_breakpoint => {
            type => 'String',
            doc  => 'Get reads with start position bp into the right breakpoint, comma separated, default [50,100,150]',
        },
        max_polymorphism_rate => {
            type => 'Number',
            doc  => 'Maximally allowed polymorphism rate in the flanking region',
            default_value => 0.02,
        },
        cm_sub_penalty => {
            type => 'Number',
            doc  => 'Substitution penalty in cross_match alignment',
            default_value => -10,
        },
        cm_gap_init_penalty => {
            type => 'Number',
            doc  => 'Gap Initialization penalty in cross_match alignment',
            default_value => -10,
        },
        chr_prefix => {
            type => 'Boolean',
            doc  => 'Prefix reference name with \'chr\' when fetching reads using samtools view',
        },
        assemble_mouse => {
            type => 'Boolean',
            doc  => 'Assemble Mouse calls, NCBI reference build 37',
        },
        avg_read_depth_limit => {
            type => 'Integer',
            doc  => 'Ignore cases that have average read depth greater than',
            default_value => 1000,
        },
        single_chr => {
            type => 'Sting',
            doc  => 'Specify a single chromosome',
        },
        min_region_size => {
            type => 'Number',
            doc  => 'Minimal size of the region to analysis',
            default_value => 0,
        },
        min_breakdancer_score => {
            type => 'Number',
            doc  => 'minimal BreakDancer score required for analysis',
            default_value => 0,
        },
        min_support_reads => {
            type => 'Integer',
            doc  => 'minimal number of supporting reads',
            default_value => 0,
        },
        sv_type => {
            type => 'String',
            doc  => 'type of sv',
        },
        skip_libraries => {
            type => 'String',
            doc  => 'Ingore calls supported by libraries that contains (comma separated)',
        },
        supple_read_dir => {
            type => 'String',
            doc  => 'A directory that contains a set of supplementary reads (when they are missing from the main data stream)',
        },
        supple_read_dup_times => {
            type => 'Integer',
            doc  => 'Duplicate times of supplementary reads',
            default_value => 3,
        },
        extra_columns => {
            type => 'Boolean',
            doc  => 'Attach assembly results as additional columns in the input file',
        },
        _bp_io => {
            type => 'SCALAR',
        },
        _sv_fh => {
            type => 'SCALAR',
        },
        _out_fh => {
            type => 'SCALAR',
        },
        _cm_aln_fh => {
            type => 'SCALAR',
        },
        _unc_pred_fh => {
            type => 'SCALAR',
        }
    ],
};

        
sub execute {
    my $self = shift;
    
    my $sv_file = $self->sv_file;
    my $sv_fh   = Genome::Utility::FileSystem->open_file_for_reading($sv_file) or return;
    $self->_sv_fh($sv_fh);

    my $out_file= $self->output_file;
    my $out_fh  = Genome::Utility::FileSystem->open_file_for_writing($out_file) or return;
    $self->_out_fh($out_fh);

    my $bp_file = $self->breakpoint_seq_file;
    if ($bp_file) {
        if (-s $bp_file) {
            $self->warning_message('breakpoint seq file: '.$bp_file. ' existing, Now remove it');
            unlink $bp_file;
        }
        my $bp_io = Bio::SeqIO->new(
            -file   => ">>$bp_file",
            -format => 'Fasta',
        );
        $self->_bp_io($bp_io);
    }

    my $cm_aln_file = $self->cm_aln_file;
    if ($cm_aln_file) {
        my $cm_aln_fh = Genome::Utility::FileSystem->open_file_for_writing($cm_aln_file) or return;
        $self->_cm_aln_fh($cm_aln_fh);
    }

    my $unc_pred_file = $self->unconfirm_predict_file;
    if ($unc_pred_file) {
        my $unc_pred_fh = Genome::Utility::FileSystem->open_file_for_writing($unc_pred_file) or return;
        $self->_unc_pred_fh($unc_pred_fh);
    }

    my @SVs;
    if ($self->custom_sv_format) {
        @SVs = $self->_ReadCustomized;
    }
    else {
        @SVs = $self->_ReadBDCoor;
    }

    if ($self->extra_columns) {
        $out_fh->print("#Chr1\tPos1\tOrientation1\tChr2\tPos2\tOrientation2\tType\tSize\tScore\tnum_Reads\tnum_Reads_lib\tAllele_frequency\tVersion\tRun_Param\tAsmChr1\tAsmStart1\tAsmChr2\tAsmStart2\tAsmOri\tAsmSize\tAsmHet\tAsmScore\tAlnScore\twAsmScore\n");
    }
    else {
        $out_fh->print("\#CHR1\tPOS1\tCHR2\tPOS2\tORI\tSIZE\tTYPE\tHET\twASMSCORE\tTRIMMED_CONTIG_SIZE\tALIGNED\%\tNUM_SEG\tNUM_FSUB\tNUM_FINDEL\tBP_FINDEL\tMicroHomology\tMicroInsertion\tPREFIX\tASMPARM\n");
    }

    srand(time ^ $$);

    for my $SV (@SVs) {
        my ($chr1,$start,$chr2,$end,$type,$size) = ($SV->{chr1},$SV->{pos1},$SV->{chr2},$SV->{pos2},$SV->{type},$SV->{size});
        $chr1 =~ s/chr//; 
        $chr2 =~ s/chr//;
        next unless $start=~/^\d/ && $end=~/^\d/ && $size=~/^\d/;
        my $SVline = $SV->{line};

        my $datadir;
        unless ($self->intermediate_read_dir) {
            if (defined $self->intermediate_save_dir) {
                $datadir = "/tmp/chr$chr1.$start.$end.$type.$size";
                mkdir $datadir;
            }
            else {
                $datadir = File::Temp::tempdir("SV_Assembly_XXXXXX", DIR => '/tmp', CLEANUP => 1);
            }
        }
        else {
            $datadir = $self->intermediate_read_dir;
        }
        $self->status_message("Data directory: $datadir");

        if ($chr1 eq $chr2 && $start > $end) {
            my $tmp = $start;
            $start  = $end;
            $end    = $tmp;
        }
        my $prefix = join('.', $chr1, $start, $chr2, $end, $type, $size, '+-');
        $self->_AssembleBestSV($datadir, $prefix, $SVline);

        if ($chr1 ne $chr2) {   #reciprocal translocations
            for my $ori ('++', '--', '-+') {
                $prefix = join('.', $chr1, $start, $chr2, $end, $type, $size, $ori);
                $self->_AssembleBestSV($datadir, $prefix, $SVline);
            }
        }
        #keep
        if (!defined $self->intermediate_read_dir and defined $self->intermediate_save_dir) {
            my $cmd = "mv -f $datadir " . $self->intermediate_save_dir;
            system $cmd;
        }
        elsif (!defined $self->intermediate_read_dir){
            File::Temp::cleanup();
        }
    }

    $self->_sv_fh->close;
    $self->_out_fh->close;
    $self->_cm_aln_fh->close   if $self->_cm_aln_fh;
    $self->_unc_pred_fh->close if $self->_unc_pred_fh;
    $self->status_message('AllDone');

    return 1;
}


sub _AssembleBestSV {
    my ($self, $datadir, $prefix, $SVline) = @_;
    my $maxSV;
    my ($chr1,$start,$chr2,$end,$type,$size,$ori) = split /\./, $prefix;
    if ($self->chr_prefix) {
        $chr1 = "chr$chr1";
        $chr2 = "chr$chr2";
    }

    my $refpad = 200;
    my @as    = (50, 100, 150);
    my $a_str = $self->start_pos_to_left_breakpoint;
    if ($a_str) {
        unless ($a_str =~ /\,/) {
            die "start_pos_to_left_breakpoint must be comma-separated: $a_str\n";
        }
        @as = split /\,/, $a_str;
    }

    my @bs    = (50, 100, 150);
    my $b_str = $self->start_pos_to_right_breakpoint;
    if ($b_str) {
        unless ($b_str =~ /\,/) {
            die "start_pos_to_right_breakpoint must be comma-separated: $b_str\n";
        }
        @bs = split /\,/, $b_str;
    }

    my $flank_size      = $self->flank_size;
    my $map_qual_to_asm = $self->map_qual_to_asm;

    my $cm_cmd_opt = '-bandwidth 20 -minmatch 20 -minscore 25 -penalty '.$self->cm_sub_penalty.' -discrep_lists -tags -gap_init '.$self->cm_gap_init_penalty.' -gap_ext -1';

    for my $a (@as) {
        for my $b (@bs) {
            my ($seqlen, $nreads, $makeup_size) = (0, 0, 0);
            my %readhash;
            my ($start1, $end1, $start2, $end2, $regionsize, $posstr);
            my (@refs, @samtools);

            $self->status_message("a:$a\tb:$b");
            my @bam_files;
            if ($self->bam_files =~ /\,/) {
                @bam_files = split /\,/, $self->bam_files; #TODO validation check each file
            }
            else {
                @bam_files = ($self->bam_files);
            }

            for my $fbam (@bam_files) {
                unless (-s $fbam.'.bai') {
                    die "bam index file: $fbam.bai does not exist";
                }
	            if ($type eq 'ITX') {
	                $start1 = $start - $b;
	                $end1   = $start + $self->est_max_ins_size;
	                $start2 = $end - $self->est_max_ins_size;
	                $end2   = $end + $a;
                }
	            elsif ($type eq 'INV') {
	                $start1 = $start - $flank_size;
	                $end1   = $start + $flank_size;
	                $start2 = $end - $flank_size;
	                $end2   = $end + $flank_size;
                }
	            else {
	                $start1 = $start - $flank_size;
	                $end1   = $start + $a;
	                $start2 = $end - $b;
	                $end2   = $end + $flank_size;
                }

	            if ($ori eq '+-' && ($chr1 eq $chr2 && $start2 < $end1)) {
	                push @refs, join(':', $chr1, $start-$flank_size-$refpad,$end+$flank_size+$refpad);
	                $regionsize = $end2 - $start1;
	                $posstr = join("_",$chr1,$start1-$refpad,$chr1,$start1-$refpad,$type,$size,$ori);
	                push @samtools, "samtools view -q ".$map_qual_to_asm." $fbam $chr1:$start1\-$end2 | cut -f1,10";
                }
	            else {
	                if ($type eq 'CTX') {
	                    push @refs, join(':',$chr1,$start-$flank_size-$refpad,$start+$flank_size+$refpad);
	                    push @refs, join(':',$chr2,$end-$flank_size-$refpad,$end+$flank_size+$refpad);
	                    $posstr = join("_",$chr1,$start-$flank_size-$refpad,$chr2,$end-$flank_size-$refpad,$type,$size,$ori);
                    }
	                elsif ($type eq 'DEL' && $size > 9999){
	                    push @refs, join(':',$chr1,$start-$flank_size-$refpad,$start+$flank_size);
	                    push @refs, join(':',$chr2,$end-$flank_size,$end+$flank_size+$refpad);
	                    $makeup_size = ($end-$flank_size)-($start+$flank_size)-1;
	                    $posstr = join("_",$chr1,$start-$flank_size-$refpad,$chr2,$end-$flank_size-$refpad,$type,$size,$ori);
                    }
	                else {
	                    push @refs, join(':',$chr1,$start-$flank_size-$refpad,$end+$flank_size+$refpad);
	                    $posstr = join("_",$chr1,$start1-$refpad,$chr1,$start1-$refpad,$type,$size,$ori);
                    }
	
	                my ($reg1, $reg2);
	                if ($ori eq '+-') {
	                    $reg1 = $chr1 .':'.$start1.'-'.$end1;
	                    $reg2 = $chr2 .':'.$start2.'-'.$end2;
                    }
	                elsif ($ori eq '-+') {
	                    $reg1 = $chr2 .':'.($end-$flank_size).'-'.($end+$a);
	                    $reg2 = $chr1 .':'.($start-$b).'-'.($start+$flank_size);
                    }
	                elsif ($ori eq '++') {
	                    $reg1 = $chr1 .':'.($start-$flank_size).'-'.($start+$a);
	                    $reg2 = $chr2 .':'.($end-$flank_size).'-'.($end+$b);
                    }
	                elsif ($ori eq '--') {
	                    $reg1 = $chr1 .':'.($start-$a).'-'.($start+$flank_size);
	                    $reg2 = $chr2 .':'.($end-$b).'-'.($end+$flank_size);
                    }
	                else{
                    }
	                $regionsize = $a+$b+2*$flank_size;
	                push @samtools, 'samtools view -q '.$map_qual_to_asm." $fbam $reg1 | cut -f1,10";	
	                push @samtools, 'samtools view -q '.$map_qual_to_asm." $fbam $reg2 | cut -f1,10";
                }
            }

            my $cmd;
            my $int_read_dir = $self->intermediate_read_dir;
            my $sup_read_dir = $self->supple_read_dir;

            if (!defined $int_read_dir || !-s "$datadir/$prefix.a$a.b$b.stat") {
	            #create reference
	            if (-s "$datadir/$prefix.ref.fa" && !defined $int_read_dir){
	                #`rm $datadir/$prefix.ref.fa`;
                    unlink "$datadir/$prefix.ref.fa";
                }
	            for my $ref(@refs) {
	                my ($chr_ref, $start_ref, $end_ref) = split /\:/, $ref;
	                if ($self->assemble_mouse) {  #Mice
	                    $cmd = "expiece $start_ref $end_ref /gscmnt/839/info/medseq/reference_sequences/NCBI-mouse-build37/${chr_ref}.fasta >> $datadir/$prefix.ref.fa";
                    }
	                else{
	                    $cmd = "expiece $start_ref $end_ref /gscuser/kchen/sata114/kchen/Hs_build36/all_fragments/Homo_sapiens.NCBI36.45.dna.chromosome.${chr_ref}.fa >> $datadir/$prefix.ref.fa";
                    }

	                if (!defined $int_read_dir) {
	                    system($cmd);
	                    $self->status_message("expiece command: $cmd");
                    }
                }

	            if ($makeup_size > 0) {  #piece together 2 refs as one
	                `head -n 1 $datadir/$prefix.ref.fa > $datadir/$prefix.ref.fa.tmp`;
	                `grep -v fa $datadir/$prefix.ref.fa >> $datadir/$prefix.ref.fa.tmp`;
	                `mv $datadir/$prefix.ref.fa.tmp $datadir/$prefix.ref.fa`;
                }
	
                my $freads = "$datadir/$prefix.a$a.b$b.fa";
	            if (!-s $freads || !defined $int_read_dir) {
	                my @buffer;
	                for my $scmd (@samtools) {
	                    my $tmp = `$scmd`;
	                    $self->status_message("samtools command: $scmd");
	                    if (defined $tmp) {
	                        my $idx = 0;
	                        for my $l (split /\s+/, $tmp) {
		                        push @buffer, $l;
		                        if ((++$idx)%2 == 0) {
		                            $seqlen += length($l);
		                            $nreads++;
                                }
                            }
                        }
                    }
	                return if $nreads <= 0;
	                my $avgseqlen = $seqlen/$nreads;
                    #open(OUT,">$datadir/$prefix.a$a.b$b.fa") || die "unable to open $datadir/$prefix.a$a.b$b.fa\n";
                    my $fa_fh = Genome::Utility::FileSystem->open_file_for_writing("$datadir/$prefix.a$a.b$b.fa") or die;
	                while (@buffer) {
	                    $fa_fh->printf(">%s\n", shift @buffer);
	                    my $sequence = shift @buffer;
	                    $fa_fh->printf("%s\n", $sequence);
	                    $readhash{uc($sequence)} = 1 if $sup_read_dir;
                    }
	                if ($self->homo_var_het) {  # add synthetic wildtype reads, making homo to het
	                    my $reflen = $end2-$start1+1;
	                    my $nr  = 0;
	                    my $in  = Bio::SeqIO->newFh(-file => "$datadir/$prefix.ref.fa" , '-format' => 'Fasta');
	                    my $seq = <$in>;
	                    # do something with $seq
	                    my $refseq = $seq->seq();
	                    while ($nr < $nreads) {
	                        my $rpos   = rand()*$reflen;
	                        my $refpos = $start1+$rpos;
	                        next if $refpos > $end1 && $refpos < $start2;
	                        $nr++;
	                        my $readseq = substr($refseq, $rpos, $avgseqlen);
	                        $fa_fh->printf(">Synthetic%dWildtype%d\n", $refpos, $nr);
	                        $fa_fh->printf("%s\n", $readseq);
                        }
                    }
	                if ($sup_read_dir &&  -s "$sup_read_dir/$prefix.fa" ) {  # the makeup reads
	                    my $idx = 0;
                        my $sup_fh = Genome::Utility::FileSystem->open_file_for_reading("$sup_read_dir/$prefix.fa") or die;
	                    while (my $l = $sup_fh->getline) {
	                        chomp $l;
	                        my $header   = $l;
	                        my $sequence = $sup_fh->getline; 
                            chomp $sequence;
	                        next if defined $readhash{uc($sequence)};
	                        for (my $ii=0;$ii<$self->supple_read_dup_times;$ii++) {
		                        $fa_fh->print("$header.$idx\n");
		                        $fa_fh->print("$sequence\n");
		                        $idx++;
                            }
                        }
                    }
	                $fa_fh->close;
	                return if $regionsize <= 0;
	                $regionsize += 2*$avgseqlen;
	                my $avgdepth = $regionsize > 0 ? $seqlen/$regionsize : 0;
	                return if $avgdepth <= 0 || $avgdepth > $self->avg_read_depth_limit;  #skip high depth region
                }

	            #Assemble
                #$cmd = "/gscuser/kchen/1000genomes/analysis/scripts/tigra_work/tigra.pl -h $datadir/$prefix.a$a.b$b.fa.contigs.het.fa -o $datadir/$prefix.a$a.b$b.fa.contigs.fa -k15,25 $datadir/$prefix.a$a.b$b.fa";
                $cmd = "/gscuser/kchen/1000genomes/analysis/scripts/toSystems_19July2010/tigra/tigra.pl -h $datadir/$prefix.a$a.b$b.fa.contigs.het.fa -o $datadir/$prefix.a$a.b$b.fa.contigs.fa -k15,25 $datadir/$prefix.a$a.b$b.fa";

	            if (!defined $int_read_dir || !-s "$datadir/$prefix.a$a.b$b.fa.contigs.fa" || !-s "$datadir/$prefix.a$a.b$b.fa.contigs.het.fa") {
	                $self->status_message("tigra command: $cmd");
	                system($cmd);
                }
	            #test homo contigs
	            $cmd = "cross_match $datadir/$prefix.a$a.b$b.fa.contigs.fa $datadir/$prefix.ref.fa $cm_cmd_opt > $datadir/$prefix.a$a.b$b.stat 2>/dev/null";
	            system($cmd);
	            $self->status_message("Cross_match for homo contigs: $cmd");
            }
            #$cmd = "/gscuser/kchen/1000genomes/analysis/scripts/getCrossMatchIndel_ctx.pl -c $datadir/$prefix.a$a.b$b.fa.contigs.fa -r $datadir/$prefix.ref.fa -m $opts{S} -x $posstr $datadir/$prefix.a$a.b$b.stat";
            my $tmp = File::Temp->new(
                DIR      => '/tmp',
                TEMPLATE => 'CM_homo_out.XXXXXX',
                UNLINK  => 1,
            );
            my $tmp_out = $tmp->filename;

            my $tmp2 = File::Temp->new(
                DIR      => '/tmp',
                TEMPLATE => 'CM_het_out.XXXXXX',
                UNLINK  => 1,
            );
            my $tmp_out2 = $tmp2->filename;

            $self->status_message('GetCrossMatchIndel for homo');
            my $cm_indel = Genome::Model::Tools::Sv::CrossMatchForIndel->create(
                output_file          => $tmp_out,
                cross_match_file     => "$datadir/$prefix.a$a.b$b.stat",
                local_ref_seq_file   => "$datadir/$prefix.ref.fa",
                assembly_contig_file => "$datadir/$prefix.a$a.b$b.fa.contigs.fa",
                per_sub_rate         => $self->max_polymorphism_rate,
                ref_start_pos        => $posstr,
            );
            $cm_indel->execute;
            my $result  = read_file($tmp_out);
            my $N50size = _ComputeTigraN50("$datadir/$prefix.a$a.b$b.fa.contigs.fa");
            my $DepthWeightedAvgSize = _ComputeTigraWeightedAvgSize("$datadir/$prefix.a$a.b$b.fa.contigs.fa");

            if (defined $result && $result =~ /\S+/) {
	            $maxSV = $self->_UpdateSVs($datadir,$maxSV,$prefix,$a,$b,$result,$N50size,$DepthWeightedAvgSize,$makeup_size,$regionsize);
            }

            if (!defined $int_read_dir || !-s "$datadir/$prefix.a$a.b$b.het.stat") {
	            #produce het contigs
	            #test het contigs
	            $cmd = "cross_match $datadir/$prefix.a$a.b$b.fa.contigs.het.fa $datadir/$prefix.ref.fa $cm_cmd_opt > $datadir/$prefix.a$a.b$b.het.stat 2>/dev/null";
	            $self->status_message("Cross_match for het contigs: $cmd");
	            system($cmd);
            }
            #$cmd = "/gscuser/kchen/1000genomes/analysis/scripts/getCrossMatchIndel_ctx.pl -c $datadir/$prefix.a$a.b$b.fa.contigs.het.fa -r $datadir/$prefix.ref.fa -m $opts{S} -x $posstr $datadir/$prefix.a$a.b$b.het.stat";
            $self->status_message("GetCrossMatchIndel for het");
            $cm_indel = Genome::Model::Tools::Sv::CrossMatchForIndel->create(
                output_file          => $tmp_out2,
                cross_match_file     => "$datadir/$prefix.a$a.b$b.het.stat",
                local_ref_seq_file   => "$datadir/$prefix.ref.fa",
                assembly_contig_file => "$datadir/$prefix.a$a.b$b.fa.contigs.het.fa",
                per_sub_rate         => $self->max_polymorphism_rate,
                ref_start_pos        => $posstr,
            );
            $cm_indel->execute;
            $result = read_file($tmp_out2);
            if (defined $result && $result=~/\S+/) {
	            $maxSV = $self->_UpdateSVs($datadir,$maxSV,$prefix,$a,$b,$result,$N50size,$DepthWeightedAvgSize,$makeup_size,$regionsize,1);
            }
        }
    }

    if (defined $maxSV && ($type eq 'CTX' && $maxSV->{type} eq $type ||
	    $type eq 'INV' && $maxSV->{type} eq $type ||
		(($type eq $maxSV->{type} && $type eq 'DEL') ||
		($type eq 'ITX' && ($maxSV->{type} eq 'ITX' || $maxSV->{type} eq 'INS')) ||
		($type eq 'INS' && ($maxSV->{type} eq 'ITX' || $maxSV->{type} eq 'INS'))) &&
		$maxSV->{size} >= $self->min_size_of_confirm_asm_sv && (!defined $self->invalid_indel_range || abs($maxSV->{size}-$size)<=$self->invalid_indel_range))
    ) {
        my $scarstr = $maxSV->{scarsize}>0 ? substr($maxSV->{contig},$maxSV->{bkstart}-1,$maxSV->{bkend}-$maxSV->{bkstart}+1) : '-';
        my $out_fh  = $self->_out_fh;

        if($self->extra_columns) {
            $out_fh->printf("%s\t%s\t%d\t%s\t%d\t%s\t%d\t%s\t%d\t%d\t%d%%\t%d\t%d\t%d\t%d\t%d\t%s\ta%d.b%d\n",$SVline,$maxSV->{chr1},$maxSV->{start1},$maxSV->{chr2},$maxSV->{start2},$maxSV->{ori},$maxSV->{size},$maxSV->{het},$maxSV->{weightedsize},$maxSV->{read_len},$maxSV->{fraction_aligned}*100,$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{microhomology},$scarstr,$maxSV->{a},$maxSV->{b});
        }
        else{
            $out_fh->printf("%s\t%d(%d)\t%s\t%d(%d)\t%s\t%d(%d)\t%s(%s)\t%s\t%d\t%d\t%d\%\t%d\t%d\t%d\t%d\t%d\t%s\t%s\ta%d.b%d\n",$maxSV->{chr1},$maxSV->{start1},$start,$maxSV->{chr2},$maxSV->{start2},$end,$maxSV->{ori},$maxSV->{size},$size,$maxSV->{type},$type,$maxSV->{het},$maxSV->{weightedsize},$maxSV->{read_len},$maxSV->{fraction_aligned}*100,$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{microhomology},$scarstr,$prefix,$maxSV->{a},$maxSV->{b});
        }

        my $bp_io     = $self->_bp_io;
        my $cm_aln_fh = $self->_cm_aln_fh;

        if ($bp_io) {  #save breakpoint sequence
            my $coord = join(".",$maxSV->{chr1},$maxSV->{start1},$maxSV->{chr2},$maxSV->{start2},$maxSV->{type},$maxSV->{size},$maxSV->{ori});
            my $contigsize = length($maxSV->{contig});
            my $seqobj = Bio::Seq->new( 
                -display_id => "ID:$prefix,Var:$coord,Ins:$maxSV->{bkstart}\-$maxSV->{bkend},Length:$contigsize,Strand:$maxSV->{strand},TIGRA_Assembly_Score:$maxSV->{weightedsize}",
                -seq => $maxSV->{contig}, 
            );
            $bp_io->write_seq($seqobj);
        }

        if ($cm_aln_fh) {
            $cm_aln_fh->printf("%s\t%d(%d)\t%s\t%d(%d)\t%s\t%d(%d)\t%s(%s)\t%s\t%d\t%d\t%d\%\t%d\t%d\t%d\t%d\t%d\t%s\t%s\ta%d.b%d\n",$maxSV->{chr1},$maxSV->{start1},$start,$maxSV->{chr2},$maxSV->{start2},$end,$maxSV->{ori},$maxSV->{size},$size,$maxSV->{type},$type,$maxSV->{het},$maxSV->{weightedsize},$maxSV->{read_len},$maxSV->{fraction_aligned}*100,$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{microhomology},$scarstr,$prefix,$maxSV->{a},$maxSV->{b});
            for my $aln (split /\,/, $maxSV->{alnstrs}) {
	            $cm_aln_fh->printf("%s\n", join("\t", split /\|/, $aln));
            }
            $cm_aln_fh->print("\n");
        }
    }
    elsif ($self->_unc_pred_fh) {
        $self->_unc_pred_fh->printf("%s\t%d\t%s\t%d\t%s\t%d\t%s\n",$chr1,$start,$chr2,$end,$type,$size,$ori);
    }
    return 1;
}


sub _UpdateSVs{
    my ($self,$datadir,$maxSV,$prefix,$a,$b,$result,$N50size,$depthWeightedAvgSize,$makeup_size,$regionsize,$het) = @_;
    if (defined $result) {
        my ($pre_chr1,$pre_start1,$pre_chr2,$pre_start2,$ori,$pre_bkstart,$pre_bkend,$pre_size,$pre_type,$pre_contigid,$alnscore,$scar_size,$read_len,$fraction_aligned,$n_seg,$n_sub,$n_indel,$nbp_indel,$strand,$microhomology,$alnstrs) = split /\s+/, $result;
        $pre_size += $makeup_size if $n_seg >= 2;
        if (defined $pre_size && defined $pre_start1 && defined $pre_start2) {
            my $fcontig = $het ? "$datadir/$prefix.a$a.b$b.fa.contigs.het.fa" : "$datadir/$prefix.a$a.b$b.fa.contigs.fa";
            my $contigseq = _GetContig($fcontig, $pre_contigid, $prefix);
            $alnscore = int($alnscore*100/$regionsize); 
            $alnscore = $alnscore>100 ? 100 : $alnscore;
            if (!defined $maxSV || $maxSV->{size}<$pre_size || $maxSV->{alnscore} < $alnscore) {
	            my $N50score = int($N50size*100/$regionsize); 
                $N50score = $N50score>100 ? 100 : $N50score;
	            if ($self->assemble_mouse) {  #Mouse
	                $pre_chr1 =~ s/.*\///; 
                    $pre_chr1 =~ s/\.fasta//;
	                $pre_chr2 =~ s/.*\///; 
                    $pre_chr2 =~ s/\.fasta//;
                }
	            ($maxSV->{chr1},$maxSV->{start1},$maxSV->{chr2},$maxSV->{start2},$maxSV->{bkstart},$maxSV->{bkend},$maxSV->{size},$maxSV->{type},$maxSV->{contigid},$maxSV->{contig},$maxSV->{N50},$maxSV->{weightedsize},$maxSV->{alnscore},$maxSV->{scarsize},$maxSV->{a},$maxSV->{b},$maxSV->{read_len},$maxSV->{fraction_aligned},$maxSV->{n_seg},$maxSV->{n_sub},$maxSV->{n_indel},$maxSV->{nbp_indel},$maxSV->{strand},$maxSV->{microhomology}) = ($pre_chr1,$pre_start1,$pre_chr2,$pre_start2,$pre_bkstart,$pre_bkend,$pre_size,$pre_type,$pre_contigid,$contigseq,$N50score,$depthWeightedAvgSize,$alnscore,$scar_size,$a,$b,$read_len,$fraction_aligned,$n_seg,$n_sub,$n_indel,$nbp_indel,$strand,$microhomology);
	            $maxSV->{het} = $het ? 'het' : 'homo';
	            $maxSV->{ori} = $ori;
	            $maxSV->{alnstrs} = $alnstrs;
            }
        }
    }
    return $maxSV;
}


sub _GetContig{
    my ($fin, $contigid, $prefix) = @_;
    my $in = Bio::SeqIO->newFh(-file => $fin, '-format' => 'Fasta');
    my $sequence;
    while (my $seq = <$in>) {
    # do something with $seq
        next unless $seq->id eq $contigid;
        $sequence = $seq->seq();
        last;
    }
    return $sequence;
}

sub _ReadBDCoor {
    my $self  = shift;
    my $sv_fh = $self->_sv_fh;
    my @nlibs = split /\,/, $self->skip_libraries if $self->skip_libraries;
    my @coor;

    while (my $line = $sv_fh->getline) {
        next if $line =~ /^\#/;
        chomp $line;
        my ($cr, @extra);
        (
            $cr->{chr1},
            $cr->{pos1},
            $cr->{ori1},
            $cr->{chr2},
            $cr->{pos2},
            $cr->{ori2},
            $cr->{type},
            $cr->{size},
            $cr->{score},
            $cr->{nreads},
            $cr->{nreads_lib},
            $cr->{software},
            @extra
        ) = split /\s+/, $line;
        $cr->{line} = $line;
        $cr->{size} = abs($cr->{size});

        next if $cr->{chr1} =~ /NT/ || $cr->{chr1} =~ /RIB/;
        next if $cr->{chr2} =~ /NT/ || $cr->{chr2} =~ /RIB/;

        next unless defined $cr->{pos1} && defined $cr->{pos2} && $cr->{pos1}=~/^\d+$/ && $cr->{pos2}=~/^\d+$/;
        my $sv_type    = $self->sv_type;
        my $min_size   = $self->min_region_size;
        my $single_chr = $self->single_chr;
        my $min_reads  = $self->min_support_reads;
        my $min_score  = $self->min_breakdancer_score;

        next if defined $sv_type && $sv_type ne $cr->{type} ||
	        defined $min_size && abs($cr->{size}) < $min_size ||
	        defined $min_reads && $cr->{nreads} < $min_reads ||
	        defined $min_score && $cr->{score} < $min_score ||
	        defined $single_chr && $cr->{chr1} ne $single_chr;

        if (@nlibs) {
            my $ignore = 0;
            for my $nlib (@nlibs) {
                $ignore = 1 if $cr->{nreads_lib} =~ /$nlib/;
            }
            next if $ignore > 0;
        }
        push @coor, $cr;
    }
    $sv_fh->close;
    return @coor;
}


sub _ReadCustomized {
    my $self  = shift;
    my $sv_fh = $self->_sv_fh;
    my (@coor, %hc);

    while (my $line = $sv_fh->getline) {
        chomp $line;
        my @cols = split /\t+/, $line;
        if ($line =~ /^\#/) {
            for (my $i=0;$i<=$#cols;$i++) {
	            $hc{chr1} = $i if !defined $hc{chr1} && $cols[$i] =~ /chr/i;
	            $hc{pos1} = $i if !defined $hc{pos1} && $cols[$i] =~ /start/i;
	            $hc{chr2} = $i if !defined $hc{chr2} && $cols[$i] =~ /chr2/i;
	            $hc{pos2} = $i if !defined $hc{pos2} && $cols[$i] =~ /end/i;
	            $hc{type} = $i if !defined $hc{type} && $cols[$i] =~ /type/i;
	            $hc{size} = $i if !defined $hc{size} && $cols[$i] =~ /size/i;
            }
            $hc{chr2} = $hc{chr1} if !defined $hc{chr2} && defined $hc{chr1};
            next;
        }
        die "file header in correctly formated.  Must have \#, chr, start, end, type, size.\n" 
            if !defined $hc{chr1} || !defined $hc{pos1} || !defined $hc{pos2} || !defined $hc{type} || !defined $hc{size};
        my $cr;
        $cr->{line} = $line;
        for my $k ('chr1', 'pos1', 'chr2', 'pos2', 'type', 'size') {
            $cr->{$k}=$cols[$hc{$k}];
        }

        next unless defined $cr->{pos1} && defined $cr->{pos2} && $cr->{pos1}=~/^\d+$/ && $cr->{pos2}=~/^\d+$/;
        my $sv_type    = $self->sv_type;
        my $min_size   = $self->min_region_size;
        my $single_chr = $self->single_chr;

        next if defined $sv_type && $sv_type ne $cr->{type} ||
	        defined $min_size && abs($cr->{size}) < $min_size ||
	        defined $single_chr && $cr->{chr1} ne $single_chr;
        $cr->{size} = abs($cr->{size});
        push @coor, $cr;
    }
    $sv_fh->close;
    return @coor;
}


sub _ComputeTigraN50{
    my ($contigfile) = @_;
    my @sizes;
    my $totalsize = 0;
    #open(CF,"<$contigfile") || die "unable to open $contigfile\n";
    my $fh = Genome::Utility::FileSystem->open_file_for_reading($contigfile) or return;
    while (my $l = $fh->getline){
        chomp $l;
        next unless $l =~ /^\>/;
        next if $l =~ /\*/;
        my ($id, $size, $depth, $ioc, @extra) = split /\s+/, $l;
        next if $size <= 50 && $depth < 3 && $ioc =~ /0/;
        push @sizes, $size;
        $totalsize += $size;
    }
    $fh->close;
    my $cum_size = 0;
    my $halfnuc_size = $totalsize/2;
    my $N50size;
    @sizes = sort {$a<=>$b} @sizes;
    while ($cum_size < $halfnuc_size) {
        $N50size = pop @sizes;
        $cum_size += $N50size;
    }
    return $N50size;
}


sub _ComputeTigraWeightedAvgSize{
    my $contigfile = shift;
    my $totalsize  = 0;
    my $totaldepth = 0;

    my $fh = Genome::Utility::FileSystem->open_file_for_reading($contigfile) or return;
    while (my $l = $fh->getline) {
        chomp $l;
        next unless $l =~ /^\>/;
        next if $l =~ /\*/;
        my ($id,$size,$depth,$ioc,@extra) = split /\s+/, $l;
        next if $size <= 50 && (($depth<3 && $ioc=~/0/) || $depth>500);  #skip error tips or extremely short and repetitive contigs
        $l = $fh->getline;
        chomp $l;
        #$_=<CF>; chomp;
        #next if($size<=50 && (/A{10}/ || /T{10}/ || /C{10}/ || /G{10}/));  #ignore homopolymer contig
        next if $size <= 50 && $l =~ /A{10}|T{10}|C{10}|G{10}/;
        $totalsize += $size*$depth;
        $totaldepth+= $depth;
    }
    $fh->close;
    return $totaldepth > 0 ? $totalsize/$totaldepth : 0;
}

1;

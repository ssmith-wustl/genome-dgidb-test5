package Genome::Model::Tools::Somatic::CalculatePindelReadSupport;

use strict;
use warnings;

use Genome;
use Genome::Utility::FileSystem;
use IO::File;

my %positions;
my %insertions;
my %deletions;

class Genome::Model::Tools::Somatic::CalculatePindelReadSupport {
    is => 'Command',
    has => [
        indels_all_sequences_bed_file =>{
            type => 'String',
            is_optional => 0,
            is_input => 1,
            doc => 'Indel sites to assemble in annotator input format',
        },
        pindel_output_directory => {
            type => 'String',
            is_optional => 0,
            is_input => 1,
            doc => "location of the pindel output_directory.",
        },
        refseq =>{
            type => 'String',
            is_optional => 1,
            default => Genome::Config::reference_sequence_directory() . '/NCBI-human-build36/all_sequences.fasta',
            doc => "reference sequence to use for reference assembly",
        },
        use_old_pindel => {
            type => 'Boolean',
            is_optional => 1,
            default => 0,
            doc => 'Run on pindel 0.2 or 0.1',
        },
        _dbsnp_insertions => {
            type => 'String',
            is_optional => 1,
            default => '/gscmnt/ams1102/info/info/dbsnp130_indels/insertions_start_stop_adjusted_dbsnp130',
            doc => 'dbsnp insertion file',
        },
        _dbsnp_deletions => {
            type => 'String',
            is_optional => 1,
            default => '/gscmnt/ams1102/info/info/dbsnp130_indels/deletions_adjusted_dbsnp130',
            doc => 'dbsnp deletion file',
        },
    ]
};

sub execute {
    my $self = shift;
    my $file = $self->indels_all_sequences_bed_file;
    my $dir = $self->pindel_output_directory;
    my $reference_fasta = $self->refseq;

    my $fh = IO::File->new($file);

    my %indels;
    my %answers;

    my $ifh = IO::File->new($self->_dbsnp_insertions);
    while (my $line = $ifh->getline) {
        chomp $line;
        my ($chr, $start, $stop, $id, $allele, undef) = split /\t/, $line;
        next unless ($allele =~ m/-/);
        $allele = substr($allele, 2);
        $insertions{$chr}{$start}{$stop}{'allele'}=$allele;
        $insertions{$chr}{$start}{$stop}{'id'}=$id;
    }
    $ifh->close;
    my $dfh = IO::File->new($self->_dbsnp_deletions);


    while (my $line = $dfh->getline) {
        chomp $line;
        my ($chr, $start, $stop, $id, $allele, undef) = split /\t/, $line;
        next unless ($allele =~ m/-/);
        $allele = substr($allele, 2);
        $deletions{$chr}{$start}{$stop}{'allele'}=$allele;
        $deletions{$chr}{$start}{$stop}{'id'}=$id;
    }
    $dfh->close;




    while (<$fh>){
        my $line = $_;
        my ($chr,$start,$stop,$refvar) = split /\t/, $line;
        $positions{$chr}{$start}{$stop}=$refvar;
        my ($ref,$var) = split "/", $refvar;
        $indels{$chr}{$start} = $refvar;
    }

    print "CHR\tSTART\tSTOP\tREF\tVAR\tINDEL_SUPPORT\tREFERENCE_SUPPORT\t%+STRAND\tDBSNP_ID\n";
    for my $chr (sort(keys(%indels))){
        my %indels_by_chr = %{$indels{$chr}};
        $self->process_file($chr, \%indels_by_chr, $dir);

    }

}

sub process_file {
    my $self = shift;
    my $chr = shift;
    my $indels_by_chrom = shift;
    my $dir = $self->pindel_output_directory;
    my $reference_fasta = $self->refseq;
    my $filename = $dir."/".$chr."/indels_all_sequences";
    unless(-s $filename){
        die "couldnt find ".$filename."\n";
    }
    my $pindel_output = IO::File->new($filename);
    my $pindel_config = $dir."/".$chr."/pindel.config";
    my $pconf = IO::File->new($pindel_config);
    $pconf->getline;
    my $tumor_bam = $pconf->getline;
    ($tumor_bam) = split /\s/, $tumor_bam;
    unless(-s $tumor_bam){
        die "couldnt find tumor bam reference in pindel.config at ".$tumor_bam."\n";
    }
    my %events;
    my ($chrom,$pos,$size,$type);

    while(my $line = $pindel_output->getline){
        my $normal_support=0;
        my $read = 0;
        if($line =~ m/^#+$/){
            my $call = $pindel_output->getline;
            if($call =~ m/^Chr/){
                while(1) {
                    $line = $pindel_output->getline;
                    if($line =~ m/#####/) {
                        $call = $pindel_output->getline;
                    } 
                    if($call !~ m/^Chr/) {
                        $DB::single=1;
                        last;
                    }          
                }
            }
            my $reference = $pindel_output->getline;
            my @call_fields = split /\s/, $call;
            my $type = $call_fields[1];
            my $size = $call_fields[2];   #12
                my $pos_strand = 0;
            my $neg_strand = 0;
            my $mod = ($call =~ m/BP_range/) ? 2: -1;
            my $support;
            if($self->use_old_pindel){
                $support = ($type eq "I") ? $call_fields[10+$mod] : $call_fields[12+$mod];
            } else {
                $support = $call_fields[12+$mod];
            }
            unless(defined($support)){
                print "No support. Call was:   ".$call."\n";
                die;
            }
            for (1..$support){
                $line = $pindel_output->getline;
                if($line =~ m/normal/) {
                    $normal_support=1;
                }
                if($line =~ m/\+/){
                    $pos_strand++;
                }else{
                    $neg_strand++;
                }
                $read=$line;
            }
#charris speed hack
            my ($chr,$start,$stop);
            if($self->use_old_pindel){
                $chr = ($type eq "I") ? $call_fields[4] : $call_fields[6];
                $start= ($type eq "I") ? $call_fields[6] : $call_fields[8];
                $stop = ($type eq "I") ? $call_fields[7] : $call_fields[9];
            } else {
                $chr = $call_fields[6];
                $start= $call_fields[8];
                $stop = $call_fields[9];
            }
            if($type eq 'I') {
                $start = $start - 1;
            }            
#charris speed hack
            unless(exists $indels_by_chrom->{$start}){
                next;
            }
            my @bed_line = $self->parse($call, $reference, $read);
            next unless scalar(@bed_line)>1;
            unless((@bed_line)&& scalar(@bed_line)==5){
                next;
            }
            my $type_and_size = $type."/".$size;
            $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'neg'}=$neg_strand;
            $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'pos'}=$pos_strand;
            if($normal_support){
                $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'normal'}=$normal_support;
            }else{
                $events{$bed_line[0]}{$bed_line[1]}{$type_and_size}{'bed'}=join("\t",@bed_line);
            }
        }
    }
    for $chrom (sort {$a cmp $b} (keys(%events))){
        for $pos (sort{$a <=> $b} (keys( %{$events{$chrom}}))){
            for my $type_and_size (sort(keys( %{$events{$chrom}{$pos}}))){
                unless(exists($events{$chrom}{$pos}{$type_and_size}{'normal'})){
                    my $pos_strand = $events{$chrom}{$pos}{$type_and_size}{'pos'};
                    my $neg_strand = $events{$chrom}{$pos}{$type_and_size}{'neg'};
                    my $pos_percent=0;
                    if($neg_strand==0){
                        $pos_percent = 1.0;
                    } else {
                        $pos_percent = sprintf("%.2f", $pos_strand / ($pos_strand + $neg_strand));
                    }
                    my $answer = "neg = ".$neg_strand."\tpos = ".$pos_strand." which gives % pos str = ".$pos_percent."\n";
                    my $reads = $pos_strand + $neg_strand;
                    my @stop = keys(%{$positions{$chrom}{$pos}});
                    #unless(scalar(@stop)==1){
                    #    
                    #    die "too many stop positions at ".$chrom." ".$pos."\n";
                    #}
                    my ($type,$size) = split /\//, $type_and_size;
                    my $stop = ($type eq 'I') ? $pos+2 : $pos + $size;
                    my @results = `samtools view $tumor_bam $chrom:$pos-$stop | grep -v "XT:A:M"`;
                    my $read_support=0;
                    for my $result (@results){
                        #print $result;
                        chomp $result;
                        my @details = split /\t/, $result;
                        if($result =~ /NM:i:(\d+)/){
                            if($1>2){
                                next;
                            }
                        }
                        unless($details[5] =~ m/[IDS]/){
                            if(($details[3] > ($pos - 40))&&($details[3] < ($pos -10))){
                                $read_support++;
                                #print "cigar = ".$details[5]."\n";
                            }
                        }
                    }
                    my $dbsnp_id = $self->dbsnp_lookup($events{$chrom}{$pos}{$type_and_size}{'bed'});
                    my $output = $events{$chrom}{$pos}{$type_and_size}{'bed'}."\t".$reads."\t".$read_support."\t".$pos_percent."\t$dbsnp_id\n";
                    print $output;
                }
            }
        }
    }
}

sub dbsnp_lookup {
    my $self=shift;
    my $bed_line =shift;
    my $dbsnp_id="-";
    chomp $bed_line;
    my ($chr, $start, $stop, $ref, $var) = split "\t", $bed_line;
    if($ref eq "0") {
        if(exists($insertions{$chr}{$start}{$stop}{'allele'})) {
            if ($var eq $insertions{$chr}{$start}{$stop}{'allele'}) {
                $dbsnp_id=$insertions{$chr}{$start}{$stop}{'id'};
            }
        }
    }
    else {        
        if(exists($deletions{$chr}{$start}{$stop}{'allele'})) {
            if ($ref eq $deletions{$chr}{$start}{$stop}{'allele'}) {
                $dbsnp_id=$deletions{$chr}{$start}{$stop}{'id'};
            }
        } 
    }
    return $dbsnp_id;
}





sub parse {
    my $self = shift;
    my $reference_fasta = $self->refseq;
    my ($call, $reference, $first_read) = @_;
    #parse out call bullshit
    chomp $call;
    my @call_fields = split /\s+/, $call;
    my $type = $call_fields[1];
    my $size = $call_fields[2];
    $DB::single=1 if $size == 1445;
    my ($chr,$start,$stop);
    if($self->use_old_pindel){
        $chr = ($type eq "I") ? $call_fields[4] : $call_fields[6];
        $start= ($type eq "I") ? $call_fields[6] : $call_fields[8];
        $stop = ($type eq "I") ? $call_fields[7] : $call_fields[9];
    } else {
        $chr = $call_fields[6];
        $start= $call_fields[8];
        $stop = $call_fields[9];
    }
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
        my $faidx_cmd = "$sam_default faidx " . $reference_fasta . " $chr:$start_for_faidx-$stop";
        #my $faidx_cmd = "$sam_default faidx " . $reference_fasta . " $chr:$start-$stop";
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
        #my $big_fh = $self->_big_output_fh;
        #$big_fh->print("$chr\t$start\t$stop\t$size\t$support\n");
        return undef;
    }
    return ($chr,$start,$stop,$ref,$var);
}


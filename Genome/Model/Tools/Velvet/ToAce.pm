package Genome::Model::Tools::Velvet::ToAce;

use strict;
use warnings;

use Genome;
use IO::File;
use Tie::File;
use Date::Format;
use AMOS::AmosLib;
use File::Basename;

use GSC::IO::Assembly::Ace::Writer;

class Genome::Model::Tools::Velvet::ToAce {
    is           => 'Command',
    has_many     => [
        afg_files   => {
            is      => 'String', 
            doc     => 'input velvet_asm.afg file path(s)',
        }
    ],
    has_optional => [
        out_acefile => {
            is      => 'String', 
            doc     => 'name for output acefile, default is ./velvet_asm.ace',
            default => 'velvet_asm.ace',
        },
        time        => {
            is      => 'String',
            doc     => 'timestamp inside acefile, must be sync with phd timestamp',
        },
    ],
};
        

sub help_brief {
    "This tool converts velvet output velvet_asm.afg into acefile format",
}


sub help_synopsis {
    return <<"EOS"
gt velvet to-ace --afg-files afg.1,afg.2 [--out-acefile acefile_name]
EOS
}


sub help_detail {
    return <<EOS
If give "-amos_file yes" option to run velvetg, velvet will generate velvet_asm.afg 
file that contains all contigs/reads assembly/alignment info. This tool will convert 
those info into acefile so assembly can be viewed/edited by using consed.
EOS
}


sub create {
    my $class = shift;
    my $self  = $class->SUPER::create(@_);

    for my $file ($self->afg_files) {
        my $base = basename $file;
        unless ($base =~ /\.afg$/) {
            $self->error_message("Input file must be .afg file, not $base");
            return;
        }    
        unless (-s $file) {
            $self->error_message("Input file: $file, not existing or is empty");
            return;
        }  
    }
    
    my $out_file = $self->out_acefile;
    
    $self->warning_message("out_acefile: $out_file exists and will be overwritten") 
        if -s $out_file;
        
    return $self;
}


sub execute {
    my $self = shift;
    
    my $time   = $self->time || localtime;
    my $out    = IO::File->new('>'.$self->out_acefile) or die "can't write to out_acefile\n";
    my $writer = GSC::IO::Assembly::Ace::Writer->new($out);

    my $seqinfo  = {};
    my $nReads   = 0;
    my $nContigs = 0;
    
    for my $file ($self->afg_files) {
        my $fh = IO::File->new($file) or die "can't open $file\n";
        my $seekpos = $fh->tell;

        while (my $record = getRecord($fh)){
            my ($rec, $fields, $recs) = parseRecord($record);
            my $nseqs = 0;
            my $id = $fields->{iid};

            if ($rec eq 'RED') {
                $seqinfo->{$id} = {
                    pos => $seekpos,
                    afg => $fh,
                };
            }
            elsif ($rec eq 'CTG') {
                $nContigs++;
                my $ctg_seq = $fields->{seq};
                $ctg_seq =~ s/\n//g;
                $ctg_seq =~ s/-/*/g;
                
                my $ctg_id     = 'Contig'.$fields->{iid};
                my $ctg_length = length $ctg_seq;
                
                my $ctg_qual = $fields->{qlt};
                $ctg_qual =~ s/\n//g;
                
                my @ctg_quals;
                for my $i (0..length($ctg_qual)-1) {
                    unless (substr($ctg_seq, $i, 1) eq '*') {
                        push @ctg_quals, ord(substr($ctg_qual, $i, 1)) - ord('0');
                    }
                }
                                
                my @read_pos;
                my @reads;
                my %left_pos;
                my %right_pos;
                
                for my $r (0..$#$recs) {
                    my ($srec, $sfields, $srecs) = parseRecord($recs->[$r]);
                                        
                    if ($srec eq 'TLE') {
                        my $ori_read_id = $sfields->{src};
                        unless ($ori_read_id) {
                            $self->error_message('TLE record contains no src: field');
                            return;
                        }
                        
                        my $info = $seqinfo->{$ori_read_id};
                        unless ($info) {
                            $self->error_message("Sequence of $ori_read_id not found, check RED");
                            return;
                        }
                        
                        my $read_id = $ori_read_id;
                        $read_id .= '_' . $info->{ct} if exists $info->{ct};
                        $seqinfo->{$ori_read_id}->{ct}++;

                        my $sequence = $self->get_seq($info->{afg}, $info->{pos}, $ori_read_id);
                        my ($asml, $asmr) = split /,/, $sfields->{clr};

                        ($asml, $asmr) = $asml < $asmr 
                                       ? (0, $asmr - $asml)
                                       : ($asml - $asmr, 0);
                        
                        my ($seql, $seqr) = ($asml, $asmr);

                        my $ori = ($seql > $seqr) ? 'C' : 'U';
                        $asml += $sfields->{off};
		                $asmr += $sfields->{off};

                        if ($asml > $asmr){
                            $sequence = reverseComplement($sequence);
                            my $tmp = $asmr;
			                $asmr = $asml;
			                $asml = $tmp;
			
			                $tmp  = $seqr;
			                $seqr = $seql;
			                $seql = $tmp;
                        }
                        
                        my $off = $sfields->{off} + 1;

                        $asml = 0 if $asml < 0;
		                $left_pos{$read_id}  = $asml + 1;
		                $right_pos{$read_id} = $asmr;
                       
                        my $end5 = $seql + 1;
                        my $end3 = $seqr;
                        
                        push @read_pos, {
                            type      => 'read_position',
                            read_name => $read_id,
                            u_or_c    => $ori,
                            position  => $off,
                        };
                        
                        push @reads, {
                            type              => 'read',
                            name              => $read_id,
                            padded_base_count => length $sequence,
                            info_count        => 0, 
                            tag_count         => 0,
                            sequence          => $sequence,
                            qual_clip_start   => $end5,
                            qual_clip_end     => $end3,
                            align_clip_start  => $end5,
                            align_clip_end    => $end3,
                            description       => {
                                CHROMAT_FILE => $read_id,
                                PHD_FILE     => $read_id.'.phd.1',
                                TIME         => $time,
                            },
                        }
                    }         
                }
                        
                my @base_segments = get_base_segments(\%left_pos, \%right_pos, $ctg_length);
                
                my $nBS = scalar @base_segments;
                my $nRd = scalar @read_pos;

                my $contig = {
                    type           => 'contig',
                    name           => $ctg_id,
                    base_count     => $ctg_length,
                    read_count     => $nRd,
                    base_seg_count => $nBS,
                    u_or_c         => 'U',
                    consensus      => $ctg_seq,
                    base_qualities => \@ctg_quals,
                };
                
                map{$writer->write_object($_)}($contig, @read_pos, @base_segments, @reads);
                $nReads += $nRd;
            }#if 'CTG'
            $seekpos = $fh->tell;
        }#While loop
    }#for loop
    $writer->write_object({
        type     => 'assembly_tag',
        tag_type => 'comment',
        program  => 'VelvetToAce',
        date     => time2str('%y%m%d:%H%M%S', time),
        data     => "Run by $ENV{USER}\n",
    });
    $out->close;
    
    tie(my @lines, 'Tie::File', $self->out_acefile);
    unshift @lines, sprintf('AS %d %d', $nContigs, $nReads);
    untie(@lines);
    
    return 1;
}


sub get_seq {
    my ($self, $fh, $seekpos, $id) = @_;
    my $pos = $fh->tell;

    $fh->seek($seekpos, 0);
    my $record = getRecord($fh);
    $fh->seek($pos, 0);

    unless (defined $record) {
        $self->error_message("Error for read $id : no record found");
        return;
    }

    my ($rec, $fields, $recs) = parseRecord($record);
    unless ($rec eq 'RED') {
        $self->error_message("Error for read $id : expect RED not $rec at pos $seekpos");
        return;
    }
    unless ($fields->{iid} == $id) {
        $self->error_message("Error for read $id : expect $id not ".$fields->{iid});
        return;
    }

    my $sequence = $fields->{seq};
    $sequence =~ s/\n//g;
    
    return $sequence;
}
    

sub get_base_segments {
    my ($left_pos, $right_pos, $ctg_length) = @_;
    my $prev;
    my @base_segs;
    
    for my $seq (sort{($left_pos->{$a} == $left_pos->{$b}) ?
        ($right_pos->{$b} <=> $right_pos->{$a}):
        ($left_pos->{$a} <=> $left_pos->{$b})
    } (keys %$left_pos)) {
        if (defined $prev) {
            if ($left_pos->{$seq} -1 < $left_pos->{$prev} ||
                $right_pos->{$seq} < $right_pos->{$prev}){
                next;
            }
            push @base_segs, {
                type      => 'base_segment',
                start_pos => $left_pos->{$prev},
                end_pos   => $left_pos->{$seq} - 1,
                read_name => $prev,
            };
        }
        $prev = $seq;
    }

    push @base_segs, {
        type      => 'base_segment',
        start_pos => $left_pos->{$prev},
        end_pos   => $ctg_length,
        read_name => $prev,
    };
    return @base_segs;
}
        
    
1;
#$HeadURL$
#$Id$


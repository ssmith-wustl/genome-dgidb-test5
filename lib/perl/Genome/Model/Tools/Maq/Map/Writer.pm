package Genome::Model::Tools::Maq::Map::Writer; 

use strict;
use warnings;

use Genome::InlineConfig;
use Carp;

our $libs;
BEGIN
{
    $libs = '-L/var/chroot/etch-ia32/usr/lib -L/usr/lib -L/lib ';        
};

use Inline 'C' => 'Config' => (
            CC => '/gscmnt/936/info/jschindl/gcc32/gcc',
            DIRECTORY => Genome::InlineConfig::DIRECTORY(), 
            INC => '-I/gscmnt/936/info/jschindl/inline_c_deps -I/gsc/pkg/bio/maq/zlib/include',
            CCFLAGS => '-D_FILE_OFFSET_BITS=64 -m32 ',
            LD => '/gscmnt/936/info/jschindl/gcc32/ld',
            LIBS => '-L/gscmnt/936/info/jschindl/inline_c_deps -L/gsc/pkg/bio/maq/zlib/lib -lz -lmaq '.$libs,
            NAME => __PACKAGE__
             );

sub new {
    Carp::croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = \%params;
    
    bless ($self, $class);
    
    $self->open($self->{file_name}) if($self->{file_name});
    return $self;
}


sub open
{
    my ($self, $file_name) = @_;
    $self->close() if defined $self->{output_file};
    $self->{file_name} = $file_name;
    $self->{output_file} = init_file($file_name);
}


sub close
{
    my ($self) = @_;
    close_file($self->{output_file});
    $self->{output_file} = undef;
}

sub write_record
{
    my ($self,$hash) = @_;
    return write_next_perl_record($self->{output_file},$hash);

}

sub write_header
{
    my ($self,$header) = @_;
    return _write_header($self->{output_file}, $header);

}

use Inline C => <<'END_C';

#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
#include <string.h>
#include "maqmap.h"

#define get_record(a, b) gzread(a,b, sizeof(*(b)))
#define put_record(a, b) gzwrite(a,b, sizeof(*(b)))

maqmap_t *build_map_header(SV *rec,maqmap_t *mm);
void _write_header(void * fpout, SV *header)
{
    maqmap_t *mm = maq_new_maqmap();
    maqmap_write_header(fpout,build_map_header(header,mm));
    maq_delete_maqmap(mm);
    
}

void * init_file(char *infile)
{
    static maqmap_t  mm;
    gzFile fpout =gzopen(infile, "w");    
    return (void *)fpout;
}

void close_file(void * fpin)
{
    gzclose((gzFile)fpin);
}

bit8_t * get_seq(char *bases,bit8_t *quals, bit8_t *seq, int length)
{
    seq = seq ? seq: malloc(sizeof(bit8_t)*MAX_READLEN);
    bzero(seq,sizeof(bit8_t)*MAX_READLEN);
    int i =0;
    for (i = 0; i <length; ++i)
    {
        if(bases[i] == 'n') seq[i] = 0;
        else 
        {
            switch (tolower(bases[i]))
            {
                case 'a':
                seq[i] = (0<<6)|(quals[i]-33);
                break;
                case 'c': 
                seq[i] = (1<<6)|(quals[i]-33);
                break;
                case 'g':
                seq[i] = (2<<6)|(quals[i]-33);
                break;
                case 't':    
                seq[i] = (3<<6)|(quals[i]-33);
                break;
                default:         
                printf( "Error converting sequence to maq record.\n");
                exit(1);              
            }     
        
        } 
    
    }
    return seq;

}

void get_qual(SV *qual_ref, bit8_t *quals)
{
    AV *AV_quals = (AV *)SvRV(qual_ref);
    int length = av_len(AV_quals)+1;
    int i = 0;
    for(i = 0;i<length;i++)
    {
        quals[i] = (bit8_t)SvIV(*(av_fetch(AV_quals,i, 0)));
    }

}

maqmap1_t * build_map_record(SV * rec_ref,maqmap1_t *mm)
{
    mm = mm ? mm: malloc(sizeof(maqmap1_t));
    bit8_t quals[MAX_READLEN];
    bzero(quals,MAX_READLEN*sizeof(bit8_t));
    bzero(mm,sizeof(maqmap1_t));
    HV * rec = (HV *)SvRV(rec_ref); 
    
    strcpy(mm->name, SvPV_nolen(*(hv_fetch(rec, "name",4, 0))));
    mm->size = SvIV(*(hv_fetch(rec, "size", 4, 0)));
    char *bases = SvPV(*(hv_fetch(rec, "seq",3, 0)),mm->size);
    SV *qual_ref = *(hv_fetch(rec,"qual",4,0));
    get_qual(qual_ref, quals);
    get_seq(bases,quals, mm->seq,(int)mm->size);
    mm->pos = SvIV(*(hv_fetch(rec, "pos", 3, 0)));
    mm->seqid = SvIV(*(hv_fetch(rec, "seqid", 5, 0)));
        
    mm->seq[MAX_READLEN-1] = SvIV(*(hv_fetch(rec, "single_end_map_qual", strlen("single_end_map_qual"), 0)));
    mm->map_qual = SvIV(*(hv_fetch(rec, "map_qual", 8, 0)));
    mm->alt_qual = SvIV(*(hv_fetch(rec, "alt_qual", 8, 0)));
    mm->flag = SvIV(*(hv_fetch(rec, "flag", 4, 0)));
    mm->dist = SvIV(*(hv_fetch(rec, "dist", 4, 0)));
    mm->info1 = (bit8_t)SvIV(*(hv_fetch(rec, "24bp_mismatches", strlen("24bp_mismatches"),0)));
    mm->info1 = (mm->info1<<4)&0xF0;
    mm->info1 = mm->info1 | (((bit8_t)SvIV(*(hv_fetch(rec, "mismatches", strlen("mismatches"),0))))&0x0f);
    mm->info2 = (bit8_t)SvIV(*(hv_fetch(rec, "info2", 5,0)));
    mm->c[0] = (bit8_t)SvIV(*(hv_fetch(rec, "c0", 2,0)));
    mm->c[1] = (bit8_t)SvIV(*(hv_fetch(rec, "c1", 2,0)));
    return mm;
}

static char **get_ref_name(SV *ref_name_ref)
{
    AV *AV_ref_name = (AV *)SvRV(ref_name_ref);
    int length = av_len(AV_ref_name)+1;
    char **ref_name = malloc(sizeof(char *)*length);
    int i = 0;
    
    for(i = 0;i<length;i++)
    {
        ref_name[i] = strdup(SvPV_nolen(*(av_fetch(AV_ref_name,i,0))));
    }
    return ref_name;

}
maqmap_t *build_map_header(SV * header_ref, maqmap_t * mm)
{
    mm = mm ? mm : malloc(sizeof(maqmap_t));
    bzero(mm,sizeof(maqmap_t));
    
    HV *header = (HV *)SvRV(header_ref);    
    
    mm->format = SvIV(*(hv_fetch(header, "format", strlen("format"), 0)));
    mm->n_ref = SvIV(*(hv_fetch(header, "n_ref", strlen("n_ref"), 0)));
    mm->ref_name = get_ref_name(*(hv_fetch(header, "ref_name",strlen("ref_name"), 0)));
    char * sn_mapped_reads = SvPV_nolen(*(hv_fetch(header, "n_mapped_reads", strlen("n_mapped_reads"), 0)));
    //printf("output number of mapped_reads is %s\n",sn_mapped_reads);
    char * end_ptr=NULL;
    bit64_t n_mapped_reads = strtoull(sn_mapped_reads,&end_ptr,10);
    //printf("converted output number of mapped_reads is %llu\n",n_mapped_reads);
    mm->n_mapped_reads = n_mapped_reads;
    mm->mapped_reads = NULL; //we won't allow passing reads in this way.
    return mm;
}

void write_next_perl_record(void * fpout, SV * rec)
{
    static maqmap1_t mm;
    
    build_map_record(rec,&mm);
    
    put_record((gzFile) fpout, &mm);

}
END_C
1;

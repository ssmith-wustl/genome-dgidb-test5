#this code is not quite done yet, jschindl - 5/12/2008
package Genome::Model::Tools::Maq::Map::Writer; 
our $inline_dir;
BEGIN
{
    ($inline_dir) = "$ENV{HOME}/".(`uname -a ` =~ /ia64 / ? '_Inline64' : '_Inline32');
    mkdir $inline_dir;
};

use Class::ISA;
use Inline (C =>'DATA',
            DIRECTORY => $inline_dir,
            INC => '-I/gscuser/jschindl -I/gscuser/jschindl/svn/gsc/zlib-1.2.3',
            CCFLAGS => '-D_FILE_OFFSET_BITS=64',
            LIBS => '-L/gscuser/jschindl -L/gscuser/jschindl/svn/gsc/zlib-1.2.3 -lz -lmaq',
            NAME => __PACKAGE__
            );
            
sub new {
    croak("__PACKAGE__:new:no class given, quitting") if @_ < 1;
    my ($caller, $arg, %params) = @_;
    my $caller_is_obj = ref($caller);
    my $class = $caller_is_obj || $caller;
    my $self = {};#\%params;
    
    bless ($self, $class);
    
    $self->open($self->{file_name}) if($self->{file_name});
    return $self;
}


sub open
{
    my ($self, $file_name) = @_;
    $self->close() if defined $self->{output_file};
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

1;
__DATA__
__C__

#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
#include <string.h>
#include "maqmap.h"

#define get_record(a, b) gzread(a,b, sizeof(*(b)))
#define put_record(a, b) gzwrite(a,b, sizeof(*(b)))

void write_header(void * fpout, void *mm)
{
    maqmap_write_header(fpout,mm);
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

void write_next_perl_record(void * fpout, SV * rec)
{
    static maqmap1_t mm;
    bzero(&mm,sizeof(mm));
    
    strcpy(mm.name, SvPV_nolen(*(hv_fetch((HV *)SvRV(rec), "name",4, 0))));
    mm.size = SvIV(*(hv_fetch((HV *)SvRV(rec), "size", 4, 0)));
    //mm.seq = 
    mm.pos = SvIV(*(hv_fetch((HV *)SvRV(rec), "pos", 3, 0)));
    mm.seqid = SvIV(*(hv_fetch((HV *)SvRV(rec), "seqid", 5, 0)));
    //mm.qual = 
    
    mm.seq[MAX_READLEN] = SvIV(*(hv_fetch((HV *)SvRV(rec), "single_end_map_qual", sizeof("single_end_map_qual"), 0)));

    mm.map_qual = SvIV(*(hv_fetch((HV *)SvRV(rec), "map_qual", 8, 0)));
    mm.alt_qual = SvIV(*(hv_fetch((HV *)SvRV(rec), "alt_qual", 8, 0)));
    
    mm.flag = SvIV(*(hv_fetch((HV *)SvRV(rec), "flag", 4, 0)));
    mm.dist = SvIV(*(hv_fetch((HV *)SvRV(rec), "dist", 4, 0)));
//    hv_store(rec, "24bp_mismatches",sizeof("24bp_mismatches"),newSViv(mm->info1>>4),0);
    
    put_record((gzFile) fpout, &mm);
}

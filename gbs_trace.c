/* Host-only boundaries for the unmodified HnS GBS command/register routines. */
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>
typedef uint8_t u8, bool8, vu8; typedef int8_t s8;
typedef uint16_t u16, vu16; typedef int16_t s16;
typedef uint32_t u32, bool32; typedef int32_t s32;
#define TRUE 1
#define FALSE 0
#define ARRAY_COUNT(x) (sizeof(x)/sizeof((x)[0]))
#define OPTIONS_SOUND_STEREO 1
#define SOUND_CHANNEL_SF_ON 1
static u8 registers[64];static const u8 *songData;
#define REG_ADDR_NR10 (registers+0)
#define REG_ADDR_NR11 (registers+2)
#define REG_ADDR_NR12 (registers+3)
#define REG_ADDR_NR13 (registers+4)
#define REG_ADDR_NR21 (registers+8)
#define REG_ADDR_NR22 (registers+9)
#define REG_ADDR_NR23 (registers+12)
#define REG_ADDR_NR30 (registers+16)
#define REG_ADDR_NR31 (registers+18)
#define REG_ADDR_NR32 (registers+19)
#define REG_ADDR_NR33 (registers+20)
#define REG_ADDR_NR41 (registers+24)
#define REG_ADDR_NR42 (registers+25)
#define REG_ADDR_NR43 (registers+28)
#define REG_ADDR_NR44 (registers+29)
#define REG_ADDR_NR50 (registers+32)
#define REG_ADDR_WAVE_RAM0 (registers+48)
#define T1_READ_16(p) ((p)[0]|((p)[1]<<8))
#define T1_READ_PTR(p) (songData+((p)[0]|((p)[1]<<8)|((u32)(p)[2]<<16)|((u32)(p)[3]<<24)))
struct MusicPlayerInfo {u16 gbsTempo;};
struct CgbChannel {u8 statusFlags,panMask;u32 *currentPointer;};
struct SoundInfo {struct CgbChannel cgbChans[4];};
static struct SoundInfo hostSoundInfo;
#define SOUND_INFO_PTR (&hostSoundInfo)
static struct {u8 optionsSound;} save={1};
#define gSaveBlock2Ptr (&save)
static u8 gGBSSFXActiveMask,gUsedCGBChannels;
/* SOURCE */
int main(int argc,char **argv){
 assert(argc==5);int limit=atoi(argv[4]);FILE *input=fopen(argv[1],"rb");assert(input);fseek(input,0,SEEK_END);long size=ftell(input);rewind(input);
 u8 *data=calloc(size,1);assert(fread(data,1,size,input)==size);fclose(input);songData=data;
 u32 off=strtoul(argv[2],NULL,10);assert(off+8<(u32)size);u8 count=data[off];assert(count<=4);
 struct GBSTrack tracks[4]={0};struct MusicPlayerInfo info={256};u8 active[4]={0};int frames=0;
 for(int i=0;i<4;i++)hostSoundInfo.cgbChans[i].panMask=(1<<i)|(16<<i);
 for(int i=0;i<count;i++){
  const u8*p=T1_READ_PTR(data+off+8+i*4);assert(p[0]==0xBC && p[1]==0);p+=2;
  if(p[0]==0xBB)p+=2;assert(p[0]==0xB6);int channel=p[1]%4;
  struct GBSTrack*t=&tracks[i];t->channelID=channel+1;t->nextInstruction=p+2;t->flags=1;t->volX=64;t->pan=255;t->noteUnitLength=1;
  t->isSFXChannel=p[1]>=4;t->useSFXNoteFormat=t->isSFXChannel;active[i]=1;
  if(t->isSFXChannel)gGBSSFXActiveMask|=1<<channel;
 }
 FILE*out=fopen(argv[3],"wb");assert(out);
 for(;frames<limit;frames++){
  int any=0;for(int i=0;i<count;i++)if(active[i]){active[i]=GBSMain(&info,(struct MusicPlayerTrack*)&tracks[i]);any|=active[i];}
  fwrite(registers,1,64,out);
  registers[5]&=0x7F;registers[13]&=0x7F;registers[21]&=0x7F;registers[29]&=0x7F;
  if(!any){frames++;break;}
 }
 fclose(out);printf("%d\n",frames);return 0;
}

#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <limits.h>
#include "repl_str.c"

// gcc waybar-porssisahko.c -o waybar-porssisahko && ./waybar-porssisahko

// debugging memleaks:
// gcc -ggdb3 waybar-porssisahko.c -o waybar-porssisahko_dbg && valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes ./waybar-porssisahko_dbg

#define UPPER_LIMIT 8

char value_to_rgb(float fvalue)
{
  char *newstring, *ret = NULL;
  char *red_hex, *green_hex, *blue_hex;
  int red_int, green_int, blue_int;

  // no overflows
  if (fvalue >= INT_MAX)
  {
    fvalue = INT_MAX;
  }
  else if (fvalue <= INT_MIN)
  {
    fvalue = INT_MIN;
  }

  // clamp int, not checking overflows ofc
  red_int = (fvalue * UPPER_LIMIT * 4);
  red_int = (red_int > 0 ? (red_int < 255 ? red_int : 255) : 0); 

  green_int = (255 - ((fvalue- UPPER_LIMIT) * UPPER_LIMIT * 4));
  green_int = (green_int > 0 ? (green_int < 255 ? green_int : 255) : 0); 

  blue_int = 0;
  blue_int = (blue_int > 0 ? (blue_int < 255 ? blue_int : 255) : 0); 

  // int to hex (string)
  asprintf(&red_hex, "%02X", red_int);
  asprintf(&green_hex, "%02X", green_int);
  asprintf(&blue_hex, "%02X", blue_int);

  size_t ns_len = asprintf(&newstring, "#%s%s%s", red_hex, green_hex, blue_hex);
  if (ns_len == -1)
  {
    printf("asprintf ns_len error");
    goto end_value_to_rgb;
  }

  // allocate len + 1 (1 for '\0')
  // ret = malloc(ns_len + 1);
  // strcpy adds '\0'
  // strcpy(ret, newstring);
  ret = newstring;

end_value_to_rgb:
  free(red_hex);
  free(green_hex);
  free(blue_hex);
  free(newstring);
  return *ret;
}

// Example:                       Allocation Type:     Read/Write:    Storage Location:   Memory Used (Bytes):
// ===========================================================================================================
// const char* str = "Stack";     Static               Read-only      Code segment        6 (5 chars plus '\0')
// char* str = "Stack";           Static               Read-only      Code segment        6 (5 chars plus '\0')
// char* str = malloc(...);       Dynamic              Read-write     Heap                Amount passed to malloc
// char str[] = "Stack";          Static               Read-write     Stack               6 (5 chars plus '\0')
// char strGlobal[10] = "Global"; Static               Read-write     Data Segment (R/W)  10

typedef struct
{
  int fs_year;
  int fs_month;
  int fs_day;
  int fs_hours;
  int fs_minutes;
  char fs_float1[32];
  char fs_float2[32];
  char fs_float3[32];
  char fs_float4[32];
} filestruct;

int main(int argc, char **argv)
{
  filestruct *fs = (filestruct *)malloc(48 * sizeof(filestruct));
  int scan_val, year, month, day, hours, minutes;
  float float1, float2, float3, float4;
  int index = 0;
  
  const char *filename = argv[1];
  printf("%s",argv[1]);
  FILE *filestream = fopen(filename, "r");
  if (filestream == NULL) {
    perror("Error");
    return 1;
  }
  while (EOF != (scan_val = fscanf(filestream, "%04d-%02d-%02d %02d:%02d %f %f %f %f[^\n]\n", 
            &year, &month, &day, &hours, &minutes, &float1, &float2, &float3, &float4)))
  {
    if (scan_val != 9) break;
    char *float1_str_final, *float2_str_final, *float3_str_final, *float4_str_final;
    char float1_rgb, float2_rgb, float3_rgb, float4_rgb;
    
    float1_rgb = value_to_rgb(float1);
    float2_rgb = value_to_rgb(float2);
    float3_rgb = value_to_rgb(float3);
    float4_rgb = value_to_rgb(float4);

    asprintf(&float1_str_final, "<span color='%s'>%.3f</span>", &float1_rgb, float1);
    asprintf(&float2_str_final, "<span color='%s'>%.3f</span>", &float2_rgb, float2);
    asprintf(&float3_str_final, "<span color='%s'>%.3f</span>", &float3_rgb, float3);
    asprintf(&float4_str_final, "<span color='%s'>%.3f</span>", &float4_rgb, float4);

    fs[index].fs_year = year;
    fs[index].fs_month = month;
    fs[index].fs_day = day;
    fs[index].fs_hours = hours;
    fs[index].fs_minutes = minutes;
    strcpy(fs[index].fs_float1,float1_str_final);
    strcpy(fs[index].fs_float2,float2_str_final);
    strcpy(fs[index].fs_float3,float3_str_final);
    strcpy(fs[index].fs_float4,float4_str_final);

    free(float1_str_final);
    free(float2_str_final);
    free(float3_str_final);
    free(float4_str_final);

    index++;
  }
  if (fs == NULL)
  {
    goto clean_up;
  }
  for (int i = 0; i < index; i++)
  {
    printf("%04d-%02d-%02d_%02d:%02d_%s_%s_%s_%s\n",
      fs[i].fs_year, fs[i].fs_month, fs[i].fs_day, fs[i].fs_hours, fs[i].fs_minutes,
      fs[i].fs_float1, fs[i].fs_float2, fs[i].fs_float3, fs[i].fs_float4);
  }

clean_up:
  free(fs);
  fs = NULL;
  fclose(filestream);
  return 0;
}
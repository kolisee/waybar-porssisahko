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

void value_to_rgb(char *ptr_value, float input_float)
{
  char *new_string = NULL;
  char *red_hex, *green_hex, *blue_hex;

  int red_int, green_int, blue_int;

  // no overflows
  if (input_float >= INT_MAX)
  {
    input_float = INT_MAX;
  }
  else if (input_float <= INT_MIN)
  {
    input_float = INT_MIN;
  }

  // clamp int, not checking overflows ofc
  red_int = (input_float * UPPER_LIMIT * 4);
  red_int = (red_int > 0 ? (red_int < 255 ? red_int : 255) : 0); 

  green_int = (255 - ((input_float- UPPER_LIMIT) * UPPER_LIMIT * 4));
  green_int = (green_int > 0 ? (green_int < 255 ? green_int : 255) : 0); 

  blue_int = 0;
  blue_int = (blue_int > 0 ? (blue_int < 255 ? blue_int : 255) : 0); 

  // int to hex (string)
  asprintf(&red_hex, "%02X", red_int);
  asprintf(&green_hex, "%02X", green_int);
  asprintf(&blue_hex, "%02X", blue_int);

  size_t ns_len = asprintf(&new_string, "#%s%s%s", red_hex, green_hex, blue_hex);
  if (ns_len == -1)
  {
    printf("asprintf ns_len error");
    goto end_value_to_rgb;
  }

  // change ret_value
  strcpy(ptr_value, new_string);

end_value_to_rgb:
  free(red_hex);
  free(green_hex);
  free(blue_hex);
  free(new_string);
  red_hex = green_hex = blue_hex = new_string = NULL;
  return;
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
  char fs_float1[50];
  char fs_float2[50];
  char fs_float3[50];
  char fs_float4[50];
} filestruct;

int main(int argc, char **argv)
{
  filestruct *fs = (filestruct *)malloc(48 * sizeof(filestruct));
  int scan_val, year, month, day, hours, minutes;
  float float1, float2, float3, float4;
  int index = 0;

  
  const char *filename = argv[1];
  printf("argv[1]: %s\n",argv[1]);
  FILE *filestream = fopen(filename, "r");
  if (filestream == NULL) {
    perror("Error");
    free(fs);
    return 1;
  }
  while (EOF != (scan_val = fscanf(filestream, "%04d-%02d-%02d %02d:%02d %f %f %f %f[^\n]\n", 
            &year, &month, &day, &hours, &minutes, &float1, &float2, &float3, &float4)))
  {
    if (scan_val != 9) break;
    
    char *float1_str_final, *float2_str_final, *float3_str_final, *float4_str_final;
    char float1_rgb[20], float2_rgb[20], float3_rgb[20], float4_rgb[20];

    value_to_rgb(float1_rgb, float1);
    value_to_rgb(float2_rgb, float2);
    value_to_rgb(float3_rgb, float3);
    value_to_rgb(float4_rgb, float4);

    asprintf(&float1_str_final, "<span color='%s'>%.3f</span>", float1_rgb, float1);
    asprintf(&float2_str_final, "<span color='%s'>%.3f</span>", float2_rgb, float2);
    asprintf(&float3_str_final, "<span color='%s'>%.3f</span>", float3_rgb, float3);
    asprintf(&float4_str_final, "<span color='%s'>%.3f</span>", float4_rgb, float4);

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

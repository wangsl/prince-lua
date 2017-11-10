/*
* this is a:
* time lib for lua it provide microseconds, miliseconds and seconds and diference between them 
*
* author:
* @xxleite
*
* date:
* 13:09 10/8/2011 
*
* ----------------------------------------------------------------------------
* "THE BEER-WARE LICENSE" (Revision 42):
* <xxleite@gmail.com> wrote this file. As long as you retain this notice you
* can do whatever you want with this stuff. If we meet some day, and you think
* this stuff is worth it, you can buy me a beer in return
* ----------------------------------------------------------------------------
*/

#include <stdio.h>
#include <sys/time.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#ifndef UINT
#define UINT unsigned int
#endif

static const UINT SEC  = 	2;
static const UINT MSEC = 	4;
static const UINT USEC = 	8;

static int loaded_times = 0;

/* time helper function */
static double get_time(UINT k){
  struct timeval tv;
  gettimeofday(&tv, NULL);
  if(k == SEC) return tv.tv_sec;
  else if(k == MSEC) return (tv.tv_sec + (double)((int)(tv.tv_usec*0.001) * 0.001));
  else if(k == USEC) return (tv.tv_sec + tv.tv_usec*0.000001);
  else return 0;
}

/* get miliseconds relative to seconds since EPOCH */
static int t_mili(lua_State *L)
{
  lua_pushnumber(L, get_time(MSEC));
  return 1;
}

/* get seconds since EPOCH */
static int t_seconds(lua_State *L)
{
  lua_pushnumber(L, get_time(SEC));
  return 1;
}

/* get microseconds relative to seconds since EPOCH */
static int t_micro(lua_State *L)
{
  lua_pushnumber(L, get_time(USEC));
  return 1;
}

/* register functions */
#if LUA_VERSION_NUM == 501
static const struct luaL_reg time_lib [] = {
#else
static const struct luaL_Reg time_lib [] = {
#endif
  {"getMiliseconds", t_mili},
  {"getSeconds", t_seconds},
  {"getMicroseconds", t_micro},
  {NULL, NULL}
};

/* register lib */
LUALIB_API int luaopen_time(lua_State *L)
{
#if LUA_VERSION_NUM == 501
  luaL_register(L, "time", time_lib);
#else
  luaL_newlib(L, time_lib);
#endif
  info("              : To load time.so, loaded %d times", ++loaded_times);
  return 1;
}


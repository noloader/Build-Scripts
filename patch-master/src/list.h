#ifndef __LIST_H
#define __LIST_H

#include <stdbool.h>

struct list_head {
  struct list_head *next, *prev;
};

#define LIST_HEAD_INIT(name) { &(name), &(name) }

#define LIST_HEAD(name) \
  struct list_head name = LIST_HEAD_INIT(name)

static inline void INIT_LIST_HEAD(struct list_head *list)
{
  list->next = list;
  list->prev = list;
}

static inline void
list_add (struct list_head *entry, struct list_head *head)
{
  struct list_head *next = head->next;
  entry->prev = head;
  entry->next = next;
  next->prev = head->next = entry;
}

static inline void
list_del (struct list_head *entry)
{
  struct list_head *next = entry->next;
  struct list_head *prev = entry->prev;
  next->prev = prev;
  prev->next = next;
}

static inline void
list_del_init (struct list_head *entry)
{
  list_del(entry);
  INIT_LIST_HEAD(entry);
}

static inline bool
list_empty (const struct list_head *head)
{
  return head->next == head;
}

#define list_entry(ptr, type, member) \
  (type *)( (char *)(ptr) - offsetof(type, member) )

#endif  /* __LIST_H */

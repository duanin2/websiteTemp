---
title: Posts
layout: default.liquid

data:
  language: en

pagination:
  include: All
  per_page: 20
  permalink_suffix: ./{{ num }}.html
  order: Desc
  sort_by: ["published_date"]
  date_index: ["Year", "Month"]
---
## All my blog posts!

{% for post in paginator.pages %}
- #### [{{post.title}}]({{ post.permalink }})
{% endfor %}

<nav class="pages" aria-label="Pages">
  <a href="/{{ paginator.first_index_permalink }}" aria-label="first">&lt;&lt;</a>
  {%- if paginator.previous_index_permalink %}<a href="/{{ paginator.previous_index_permalink }}" aria-label="previous">&lt;</a>{% else %}<div>&lt;</div>{% endif %}
  <a href="/{{ paginator.index_permalink }}" aria-label="current">{{ paginator.index }}</a>
  {%- if paginator.next_index_permalink %}<a href="/{{ paginator.next_index_permalink }}" aria-label="next">&gt;</a>{% else %}<div>&gt;</div>{% endif %}
  <a href="/{{ paginator.last_index_permalink }}" aria-label="last">&gt;&gt;</a>
</nav>
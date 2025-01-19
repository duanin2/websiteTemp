---
title: Posts
layout: default.liquid

data:
  language: en
---
## All my blog posts!

{% for post in collections.posts.pages %}
- #### [{{post.title}}]({{ post.permalink }})
{% endfor %}
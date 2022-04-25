#
# Copyright Elasticsearch B.V. and/or licensed to Elasticsearch B.V. under one
# or more contributor license agreements. Licensed under the Elastic License;
# you may not use this file except in compliance with the Elastic License.
#

# frozen_string_literal: true

module ConnectorsSdk
  module Fixtures
    module Atlassian
      module Confluence
        def space_response
          {
            :results => [
              {
                :id => 655361,
                :key => 'SWPRJ',
                :name => 'Demo Project Home',
                :type => 'global',
                :permissions => [
                  {
                    :operation => {
                      :operation => 'read',
                      :targetType => 'space'
                    },
                    :subjects => {
                      :user => {
                        :results => [
                          {
                            :accountId => '1234'
                          }
                        ]
                      }
                    }
                  }
                ],
                :_expandable => {
                  :metadata => '',
                  :operations => '',
                  :icon => '',
                  :description => '',
                  :homepage => '/rest/api/content/32773'
                },
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/space/SWPRJ',
                  :webui => '/spaces/SWPRJ'
                }
              }
            ],
            :start => 0,
            :limit => 25,
            :size => 1,
            :_links => {
              :base => 'https://swiftypedevelopment.atlassian.net/wiki',
              :context => '/wiki',
              :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/space'
            }
          }
        end

        def content_response
          {
            :results => [
              {
                :id => '10551886',
                :type => 'page',
                :status => 'current',
                :title => 'Backups Playbook',
                :space => {
                  :id => 3440644,
                  :key => 'eng',
                  :name => 'Engineering',
                  :type => 'global',
                  :status => 'current',
                  :_expandable => {
                    :metadata => '',
                    :operations => '',
                    :permissions => '',
                    :icon => '',
                    :description => '',
                    :homepage => '/rest/api/content/3211294'
                  },
                  :_links => {
                    :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/space/eng',
                    :webui => '/spaces/eng'
                  }
                },
                :extensions => {
                  :position => 'none'
                },
                :_expandable => {
                  :childTypes => '',
                  :container => '/rest/api/space/eng',
                  :metadata => '',
                  :operations => '',
                  :restrictions => '/rest/api/content/10551886/restriction/byOperation',
                  :version => '',
                  :descendants => '/rest/api/content/10551886/descendant'
                },
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/10551886',
                  :webui => '/display/eng/Backups+Playbook',
                  :editui => '/pages/resumedraft.action?draftId=10551886&draftShareId=9ab81a44-967b-489f-aa1a-bb4d04d7067f',
                  :tinyui => '/x/TgKh'
                }
              }
            ],
            :start => 0,
            :limit => 1,
            :size => 1,
            :_links => {
              :base => 'https://swiftypedevelopment.atlassian.net/wiki',
              :context => '/wiki',
              :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/search?expand=body.export_view,history.lastUpdated,ancestors,space,children.comment.body.export_view&cql=space=ENG+AND+type+IN+(page,blogpost)'
            }
          }
        end

        def expanded_content_response
          {
            :id => '10551886',
            :type => 'page',
            :status => 'current',
            :title => 'Backups Playbook',
            :space => {
              :id => 3440644,
              :key => 'eng',
              :name => 'Engineering',
              :type => 'global',
              :status => 'current',
              :_expandable => {
                :metadata => '',
                :operations => '',
                :permissions => '',
                :icon => '',
                :description => '',
                :homepage => '/rest/api/content/3211294'
              },
              :_links => {
                :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/space/eng',
                :webui => '/spaces/eng'
              }
            },
            :history => {
              :lastUpdated => {
                :by => {
                  :type => 'known',
                  :username => 'bvans',
                  :userKey => 'ff80808158ad128e0158ad12b4530002',
                  :profilePicture => {
                    :path => '/wiki/aa-avatar/65f9f06e83723ff9229b960535dc39db?s=48&d=https%3A%https://swiftypedevelopment.atlassian.net%2Fwiki%2Fimages%2Ficons%2Fprofilepics%2Fdefault.png%3FnoRedirect%3Dtrue',
                    :width => 48,
                    :height => 48,
                    :isDefault => false
                  },
                  :displayName => 'Brian van Staalduine',
                  :_expandable => {
                    :operations => '',
                    :details => ''
                  },
                  :_links => {
                    :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/experimental/user?key=ff80808158ad128e0158ad12b4530002'
                  }
                },
                :when => '2017-05-30T12:59:19.623-07:00',
                :friendlyWhen => '30 minutes ago',
                :message => 'document backup validation procedure',
                :number => 14,
                :minorEdit => false,
                :_expandable => {
                  :content => '/rest/api/content/10551886'
                },
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/10551886/version/14'
                }
              },
              :latest => true,
              :createdBy => {
                :type => 'known',
                :username => 'kovyrin',
                :userKey => 'ff80808159abb08c0159cd460f590000',
                :profilePicture => {
                  :path => '/wiki/aa-avatar/3a6f4838ec6c7636ef5aec7b1e8e6640?s=48&d=https%3A%https://swiftypedevelopment.atlassian.net%2Fwiki%2Fdownload%2Fattachments%2F8473534%2Fuser-avatar%3FnoRedirect%3Dtrue',
                  :width => 48,
                  :height => 48,
                  :isDefault => false
                },
                :displayName => 'Oleksiy Kovyrin',
                :_expandable => {
                  :operations => '',
                  :details => ''
                },
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/experimental/user?key=ff80808159abb08c0159cd460f590000'
                }
              },
              :createdDate => '2017-05-24T02:49:55.288-07:00',
              :_expandable => {
                :previousVersion => '',
                :contributors => '',
                :nextVersion => ''
              },
              :_links => {
                :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/10551886/history'
              }
            },
            :ancestors => [
              {
                :id => '3211294',
                :type => 'page',
                :status => 'current',
                :title => 'Engineering',
                :extensions => {
                  :position => 'none'
                },
                :_expandable => {
                  :childTypes => '',
                  :container => '/rest/api/space/eng',
                  :metadata => '',
                  :operations => '',
                  :children => '/rest/api/content/3211294/child',
                  :restrictions => '/rest/api/content/3211294/restriction/byOperation',
                  :history => '/rest/api/content/3211294/history',
                  :ancestors => '',
                  :body => '',
                  :version => '',
                  :descendants => '/rest/api/content/3211294/descendant',
                  :space => '/rest/api/space/eng'
                },
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/3211294',
                  :webui => '/display/eng/Engineering',
                  :editui => '/pages/resumedraft.action?draftId=3211294',
                  :tinyui => '/x/HgAx'
                }
              },
              {
                :id => '9609198',
                :type => 'page',
                :status => 'current',
                :title => 'Playbooks',
                :extensions => {
                  :position => 2
                },
                :_expandable => {
                  :childTypes => '',
                  :container => '/rest/api/space/eng',
                  :metadata => '',
                  :operations => '',
                  :children => '/rest/api/content/9609198/child',
                  :restrictions => '/rest/api/content/9609198/restriction/byOperation',
                  :history => '/rest/api/content/9609198/history',
                  :ancestors => '',
                  :body => '',
                  :version => '',
                  :descendants => '/rest/api/content/9609198/descendant',
                  :space => '/rest/api/space/eng'
                },
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/9609198',
                  :webui => '/display/eng/Playbooks',
                  :editui => '/pages/resumedraft.action?draftId=9609198',
                  :tinyui => '/x/7p_S'
                }
              }
            ],
            :children => {
              :comment => {
                :results => [],
                :start => 0,
                :limit => 25,
                :size => 0,
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/10551886/child/comment'
                }
              },
              :_expandable => {
                :attachment => '/rest/api/content/10551886/child/attachment',
                :page => '/rest/api/content/10551886/child/page'
              },
              :_links => {
                :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/10551886/child'
              }
            },
            :body => {
              :export_view => {
                :value => '<div class=\'contentLayout2\'>Simple value</div>',
                :representation => 'export_view',
                :_expandable => {
                  :webresource => '',
                  :embeddedContent => '',
                  :content => '/rest/api/content/10551886'
                }
              },
              :_expandable => {
                :editor => '',
                :view => '',
                :styled_view => '',
                :storage => '',
                :editor2 => '',
                :anonymous_export_view => ''
              }
            },
            :extensions => {
              :position => 'none'
            },
            :_expandable => {
              :childTypes => '',
              :container => '/rest/api/space/eng',
              :metadata => '',
              :operations => '',
              :restrictions => '/rest/api/content/10551886/restriction/byOperation',
              :version => '',
              :descendants => '/rest/api/content/10551886/descendant'
            },
            :_links => {
              :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/10551886',
              :webui => '/display/eng/Backups+Playbook',
              :editui => '/pages/resumedraft.action?draftId=10551886&draftShareId=9ab81a44-967b-489f-aa1a-bb4d04d7067f',
              :tinyui => '/x/TgKh'
            }
          }
        end

        def expanded_space_response
          {
            :id => 655361,
            :key => 'SWPRJ',
            :name => 'Demo Project Home',
            :type => 'global',
            :_expandable => {
              :metadata => '',
              :operations => '',
              :icon => '',
              :description => '',
              :homepage => '/rest/api/content/32773'
            },
            :_links => {
              :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/space/SWPRJ',
              :webui => '/spaces/SWPRJ'
            }
          }
        end

        def expanded_attachment_response
          {
            :id => 'att33012',
            :type => 'attachment',
            :status => 'current',
            :title => 'cake.jpg',
            :space => {
              :id => 98306,
              :key => 'TS',
              :name => 'Test Space',
              :type => 'global',
              :status => 'current',
              :_expandable => {
                :settings => '/rest/api/space/TS/settings',
                :metadata => '',
                :operations => '',
                :lookAndFeel => '/rest/api/settings/lookandfeel?spaceKey=TS',
                :permissions => '',
                :icon => '',
                :description => '',
                :theme => '/rest/api/space/TS/theme',
                :history => '',
                :homepage => '/rest/api/content/98307'
              },
              :_links => {
                :webui => '/spaces/TS',
                :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/space/TS'
              }
            },
            :history => {
              :lastUpdated => {
                :by => {
                  :type => 'known',
                  :accountId => '5dd6b6a99def2a0ee974f8ff',
                  :accountType => 'atlassian',
                  :email => '',
                  :publicName => 'Sean Story',
                  :profilePicture => {
                    :path => '/wiki/aa-avatar/5dd6b6a99def2a0ee974f8ff',
                    :width => 48,
                    :height => 48,
                    :isDefault => false
                  },
                  :displayName => 'Sean Story',
                  :_expandable => {
                    :operations => '',
                    :personalSpace => ''
                  },
                  :_links => {
                    :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/user?accountId=5dd6b6a99def2a0ee974f8ff'
                  }
                },
                :when => '2019-11-21T16:10:44.170Z',
                :friendlyWhen => 'Nov 21, 2019',
                :message => '',
                :number => 1,
                :minorEdit => false,
                :_expandable => {
                  :collaborators => '',
                  :content => '/rest/api/content/att33012'
                },
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/att33012/version/1'
                }
              },
              :latest => true,
              :createdBy => {
                :type => 'known',
                :accountId => '5dd6b6a99def2a0ee974f8ff',
                :accountType => 'atlassian',
                :email => '',
                :publicName => 'Sean Story',
                :profilePicture => {
                  :path => '/wiki/aa-avatar/5dd6b6a99def2a0ee974f8ff',
                  :width => 48,
                  :height => 48,
                  :isDefault => false
                },
                :displayName => 'Sean Story',
                :_expandable => {
                  :operations => '',
                  :personalSpace => ''
                },
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/user?accountId=5dd6b6a99def2a0ee974f8ff'
                }
              },
              :createdDate => '2019-11-21T16:10:44.170Z',
              :_expandable => {
                :previousVersion => '',
                :contributors => '',
                :nextVersion => ''
              },
              :_links => {
                :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/att33012/history'
              }
            },
            :ancestors => [],
            :children => {
              :comment => {
                :results => [],
                :start => 0,
                :limit => 25,
                :size => 0,
                :_links => {
                  :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/att33012/child/comment'
                }
              },
              :_links => {
                :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/att33012/child'
              }
            },
            :container => {
              :id => '32989',
              :type => 'page',
              :status => 'current',
              :title => 'This my first page',
              :macroRenderedOutput => {
              },
              :extensions => {
                :position => 430931086
              },
              :archivableDescendantsCount => 0,
              :_expandable => {
                :childTypes => '',
                :container => '/rest/api/space/TS',
                :metadata => '',
                :operations => '',
                :children => '/rest/api/content/32989/child',
                :restrictions => '/rest/api/content/32989/restriction/byOperation',
                :history => '/rest/api/content/32989/history',
                :ancestors => '',
                :body => '',
                :version => '',
                :descendants => '/rest/api/content/32989/descendant',
                :space => '/rest/api/space/TS'
              },
              :_links => {
                :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/32989',
                :tinyui => '/x/3Y',
                :editui => '/pages/resumedraft.action?draftId=32989',
                :webui => '/spaces/TS/pages/32989/This+my+first+page'
              }
            },
            :macroRenderedOutput => {
            },
            :body => {
              :export_view => {
                :value => '',
                :representation => 'export_view',
                :_expandable => {
                  :webresource => '',
                  :embeddedContent => '',
                  :mediaToken => '',
                  :content => '/rest/api/content/att33012'
                }
              },
              :_expandable => {
                :editor => '',
                :atlas_doc_format => '',
                :view => '',
                :styled_view => '',
                :dynamic => '',
                :storage => '',
                :editor2 => '',
                :anonymous_export_view => ''
              }
            },
            :metadata => {
              :mediaType => 'image/jpeg'
            },
            :extensions => {
              :mediaType => 'image/jpeg',
              :fileSize => 14638,
              :comment => '',
              :mediaTypeDescription => 'JPEG Image',
              :fileId => '08c2aed5-0a99-4d23-b53e-ad791e6f2336',
              :collectionName => 'contentId-32989'
            },
            :archivableDescendantsCount => 0,
            :_expandable => {
              :childTypes => '',
              :operations => '',
              :restrictions => '/rest/api/content/att33012/restriction/byOperation',
              :version => '',
              :descendants => '/rest/api/content/att33012/descendant'
            },
            :_links => {
              :context => '/wiki',
              :self => 'https://swiftypedevelopment.atlassian.net/wiki/rest/api/content/att33012',
              :download => '/download/attachments/32989/cake.jpg?version=1&modificationDate=1574352644170&cacheVersion=1&api=v2',
              :collection => '/rest/api/content',
              :webui => '/spaces/TS/pages/32989/This+my+first+page?preview=%2F32989%2F33012%2Fcake.jpg',
              :base => 'https://swiftypedevelopment.atlassian.net/wiki'
            }
          }
        end

        def expanded_restricted_space_response
          {
              :results => [
                  {
                      :id => 1952055299,
                      :key => '716',
                      :name => '7.16',
                      :type => 'global',
                      :permissions => [
                          {
                              :id => 1952055499,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055493,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055487,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055481,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055475,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055469,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055463,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055457,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055451,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055445,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5b70c8b80fd0ac05d389f5e9',
                                              :accountType => 'app',
                                              :email => '',
                                              :publicName => 'Chat Notifications',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5b70c8b80fd0ac05d389f5e9',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Chat Notifications',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5b70c8b80fd0ac05d389f5e9'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055428,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055427,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055426,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055424,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'archive',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055423,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055422,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055421,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055420,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055419,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055418,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055417,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055416,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055415,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055414,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055413,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055412,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055411,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055410,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055409,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055406,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055404,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055403,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055401,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055400,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055399,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055398,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055397,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055395,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055394,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055393,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055392,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055391,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055390,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055388,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055387,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055386,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055384,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055383,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055382,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055381,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055380,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055379,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055378,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055377,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055376,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055375,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055374,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055373,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055372,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055371,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055370,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055369,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055367,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055365,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055364,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055363,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055362,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055361,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055360,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055359,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055358,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055357,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055356,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055355,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055353,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055352,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055351,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055350,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055348,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055347,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055346,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055345,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055344,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055343,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055342,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055341,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055340,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055338,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055336,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055335,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055334,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055333,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055332,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055330,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055328,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055327,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055326,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055325,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055324,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'restrict_content',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055323,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-software-users',
                                              :id => '7fe97d9a-71e5-4779-b649-8ba875974704',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-software-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055322,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055321,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'administer',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055320,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055318,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055317,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055316,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055315,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055314,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'comment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055313,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055312,
                              :subjects => {
                                  :user => {
                                      :results => [
                                          {
                                              :type => 'known',
                                              :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                              :accountType => 'atlassian',
                                              :email => 'workplace-search@elastic.co',
                                              :publicName => 'Randy Swift',
                                              :timeZone => 'UTC',
                                              :profilePicture => {
                                                  :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                                  :width => 48,
                                                  :height => 48,
                                                  :isDefault => false
                                              },
                                              :displayName => 'Randy Swift',
                                              :isExternalCollaborator => false,
                                              :_expandable => {
                                                  :operations => '',
                                                  :personalSpace => ''
                                              },
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :group => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'create',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055311,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055310,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'system-administrators',
                                              :id => '1704c259-1617-43d9-85c8-54341ec3388f',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/system-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055309,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-servicedesk-users',
                                              :id => '6465ccca-2853-4e7d-918a-7b247431787b',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-servicedesk-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055308,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'site-admins',
                                              :id => '2f19762a-4962-47ca-af59-6823dcf62a3a',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/site-admins'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'attachment'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055307,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055306,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-administrators',
                                              :id => '3694a23a-dd77-4077-b873-8bd0faa64db3',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055305,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'page'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055304,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'confluence-users',
                                              :id => '501c68fc-2075-4137-bbbb-85db00648c97',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/confluence-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'delete',
                                  :targetType => 'blogpost'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055303,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'jira-core-users',
                                              :id => '63baeb53-f610-46cb-8239-e8d9b1e0d7bf',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/jira-core-users'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'read',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          },
                          {
                              :id => 1952055301,
                              :subjects => {
                                  :group => {
                                      :results => [
                                          {
                                              :type => 'group',
                                              :name => 'administrators',
                                              :id => '04e295aa-cea4-44f9-bea6-bdc88958ab09',
                                              :_links => {
                                                  :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/administrators'
                                              }
                                          }
                                      ],
                                      :size => 1
                                  },
                                  :_expandable => {
                                      :user => ''
                                  }
                              },
                              :operation => {
                                  :operation => 'export',
                                  :targetType => 'space'
                              },
                              :anonymousAccess => false,
                              :unlicensedAccess => false
                          }
                      ],
                      :status => 'current',
                      :_expandable => {
                          :settings => '/rest/api/space/716/settings',
                          :metadata => '',
                          :operations => '',
                          :lookAndFeel => '/rest/api/settings/lookandfeel?spaceKey=716',
                          :identifiers => '',
                          :icon => '',
                          :description => '',
                          :theme => '/rest/api/space/716/theme',
                          :history => '',
                          :homepage => '/rest/api/content/1952055429'
                      },
                      :_links => {
                          :webui => '/spaces/716',
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/space/716'
                      }
                  }
              ],
              :start => 0,
              :limit => 25,
              :size => 1,
              :_links => {
                  :base => 'https://workplace-search.atlassian.net/wiki',
                  :context => '/wiki',
                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/space?spaceKey=716&expand=permissions'
              }
          }
        end

        def expanded_restricted_page_response
          {
              :id => '1952186369',
              :type => 'page',
              :status => 'current',
              :title => 'Restricted Page',
              :space => {
                  :id => 1952055299,
                  :key => '716',
                  :name => '7.16',
                  :type => 'global',
                  :status => 'current',
                  :_expandable => {
                      :settings => '/rest/api/space/716/settings',
                      :metadata => '',
                      :operations => '',
                      :lookAndFeel => '/rest/api/settings/lookandfeel?spaceKey=716',
                      :identifiers => '',
                      :permissions => '',
                      :icon => '',
                      :description => '',
                      :theme => '/rest/api/space/716/theme',
                      :history => '',
                      :homepage => '/rest/api/content/1952055429'
                  },
                  :_links => {
                      :webui => '/spaces/716',
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/space/716'
                  }
              },
              :history => {
                  :lastUpdated => {
                      :by => {
                          :type => 'known',
                          :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                          :accountType => 'atlassian',
                          :email => 'workplace-search@elastic.co',
                          :publicName => 'Randy Swift',
                          :timeZone => 'UTC',
                          :profilePicture => {
                              :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                              :width => 48,
                              :height => 48,
                              :isDefault => false
                          },
                          :displayName => 'Randy Swift',
                          :isExternalCollaborator => false,
                          :_expandable => {
                              :operations => '',
                              :personalSpace => ''
                          },
                          :_links => {
                              :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                          }
                      },
                      :when => '2022-01-04T14:58:46.933Z',
                      :friendlyWhen => 'yesterday at 2:58 PM',
                      :message => '',
                      :number => 2,
                      :minorEdit => false,
                      :syncRev => '0.confluence$content$1952186369.9',
                      :syncRevSource => 'synchrony-ack',
                      :confRev => 'confluence$content$1952186369.10',
                      :contentTypeModified => false,
                      :_expandable => {
                          :collaborators => '',
                          :content => '/rest/api/content/1952186369'
                      },
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952186369/version/2'
                      }
                  },
                  :latest => true,
                  :createdBy => {
                      :type => 'known',
                      :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                      :accountType => 'atlassian',
                      :email => 'workplace-search@elastic.co',
                      :publicName => 'Randy Swift',
                      :timeZone => 'UTC',
                      :profilePicture => {
                          :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                          :width => 48,
                          :height => 48,
                          :isDefault => false
                      },
                      :displayName => 'Randy Swift',
                      :isExternalCollaborator => false,
                      :_expandable => {
                          :operations => '',
                          :personalSpace => ''
                      },
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                      }
                  },
                  :createdDate => '2022-01-04T14:34:49.457Z',
                  :_expandable => {
                      :previousVersion => '',
                      :contributors => '',
                      :nextVersion => ''
                  },
                  :_links => {
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952186369/history'
                  }
              },
              :ancestors => [
                  {
                      :id => '1952055429',
                      :type => 'page',
                      :status => 'current',
                      :title => '7.16 Home',
                      :macroRenderedOutput => {},
                      :extensions => {
                          :position => 457
                      },
                      :_expandable => {
                          :container => '/rest/api/space/716',
                          :metadata => '',
                          :restrictions => '/rest/api/content/1952055429/restriction/byOperation',
                          :history => '/rest/api/content/1952055429/history',
                          :body => '',
                          :version => '',
                          :descendants => '/rest/api/content/1952055429/descendant',
                          :space => '/rest/api/space/716',
                          :childTypes => '',
                          :operations => '',
                          :schedulePublishDate => '',
                          :children => '/rest/api/content/1952055429/child',
                          :ancestors => ''
                      },
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952055429',
                          :tinyui => '/x/hQBad',
                          :editui => '/pages/resumedraft.action?draftId=1952055429',
                          :webui => '/spaces/716/overview'
                      }
                  }
              ],
              :children => {
                  :comment => {
                      :results => [],
                      :start => 0,
                      :limit => 25,
                      :size => 0,
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952186369/child/comment'
                      }
                  },
                  :_expandable => {
                      :attachment => '/rest/api/content/1952186369/child/attachment',
                      :page => '/rest/api/content/1952186369/child/page'
                  },
                  :_links => {
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952186369/child'
                  }
              },
              :container => {
                  :id => 1952055299,
                  :key => '716',
                  :name => '7.16',
                  :type => 'global',
                  :status => 'current',
                  :_expandable => {
                      :settings => '/rest/api/space/716/settings',
                      :metadata => '',
                      :operations => '',
                      :lookAndFeel => '/rest/api/settings/lookandfeel?spaceKey=716',
                      :identifiers => '',
                      :permissions => '',
                      :icon => '',
                      :description => '',
                      :theme => '/rest/api/space/716/theme',
                      :history => '',
                      :homepage => '/rest/api/content/1952055429'
                  },
                  :_links => {
                      :webui => '/spaces/716',
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/space/716'
                  }
              },
              :macroRenderedOutput => {},
              :body => {
                  :export_view => {
                      :value => '<p>This is allowed to be seen by:</p><ol><li><p>Creator user (Randy Swift) <span class=\'status-macro aui-lozenge aui-lozenge-success\'>EDITOR</span> </p></li><li><p>View user (MC #2)</p></li><li><p>View group (Restricted Group)</p></li></ol>',
                      :representation => 'export_view',
                      :_expandable => {
                          :webresource => '',
                          :embeddedContent => '',
                          :mediaToken => '',
                          :content => '/rest/api/content/1952186369'
                      }
                  },
                  :_expandable => {
                      :editor => '',
                      :atlas_doc_format => '',
                      :view => '',
                      :styled_view => '',
                      :dynamic => '',
                      :storage => '',
                      :editor2 => '',
                      :anonymous_export_view => ''
                  }
              },
              :extensions => {
                  :position => 222367857
              },
              :restrictions => {
                  :read => {
                      :operation => 'read',
                      :restrictions => {
                          :user => {
                              :results => [
                                  {
                                      :type => 'known',
                                      :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                                      :accountType => 'atlassian',
                                      :email => 'workplace-search@elastic.co',
                                      :publicName => 'Randy Swift',
                                      :timeZone => 'UTC',
                                      :profilePicture => {
                                          :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                                          :width => 48,
                                          :height => 48,
                                          :isDefault => false
                                      },
                                      :displayName => 'Randy Swift',
                                      :isExternalCollaborator => false,
                                      :_expandable => {
                                          :operations => '',
                                          :personalSpace => ''
                                      },
                                      :_links => {
                                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                                      }
                                  },
                                  {
                                      :type => 'known',
                                      :accountId => '61d45bdbf3037f0069010539',
                                      :accountType => 'atlassian',
                                      :email => 'john.doe+2@example.com',
                                      :publicName => 'John Doe #2',
                                      :timeZone => 'UTC',
                                      :profilePicture => {
                                          :path => '/wiki/aa-avatar/61d45bdbf3037f0069010539',
                                          :width => 48,
                                          :height => 48,
                                          :isDefault => false
                                      },
                                      :displayName => 'John Doe #2',
                                      :isExternalCollaborator => false,
                                      :_expandable => {
                                          :operations => '',
                                          :personalSpace => ''
                                      },
                                      :_links => {
                                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=61d45bdbf3037f0069010539'
                                      }
                                  }
                              ],
                              :start => 0,
                              :limit => 200,
                              :size => 2
                          },
                          :group => {
                              :results => [
                                  {
                                      :type => 'group',
                                      :name => 'restricted group',
                                      :id => 'b6b2febb-2ff6-4159-bb50-91c91112791d',
                                      :_links => {
                                          :self => 'https://workplace-search.atlassian.net/wiki/rest/experimental/group/restricted%20group'
                                      }
                                  }
                              ],
                              :start => 0,
                              :limit => 200,
                              :size => 1
                          }
                      },
                      :_expandable => {
                          :content => '/rest/api/content/1952186369'
                      },
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952186369/restriction/byOperation/read'
                      }
                  },
                  :_expandable => {
                      :update => ''
                  },
                  :_links => {
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952186369/restriction/byOperation'
                  }
              },
              :_expandable => {
                  :childTypes => '',
                  :metadata => '',
                  :operations => '',
                  :schedulePublishDate => '',
                  :version => '',
                  :descendants => '/rest/api/content/1952186369/descendant'
              },
              :_links => {
                  :editui => '/pages/resumedraft.action?draftId=1952186369',
                  :webui => '/spaces/716/pages/1952186369/Restricted+Page',
                  :context => '/wiki',
                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952186369',
                  :tinyui => '/x/AQBcd',
                  :collection => '/rest/api/content',
                  :base => 'https://workplace-search.atlassian.net/wiki'
              }
          }
        end

        def expanded_restricted_page_anc_response
          {
              :id => '1952055429',
              :type => 'page',
              :status => 'current',
              :title => '7.16 Home',
              :space => {
                  :id => 1952055299,
                  :key => '716',
                  :name => '7.16',
                  :type => 'global',
                  :status => 'current',
                  :_expandable => {
                      :settings => '/rest/api/space/716/settings',
                      :metadata => '',
                      :operations => '',
                      :lookAndFeel => '/rest/api/settings/lookandfeel?spaceKey=716',
                      :identifiers => '',
                      :permissions => '',
                      :icon => '',
                      :description => '',
                      :theme => '/rest/api/space/716/theme',
                      :history => '',
                      :homepage => '/rest/api/content/1952055429'
                  },
                  :_links => {
                      :webui => '/spaces/716',
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/space/716'
                  }
              },
              :history => {
                  :lastUpdated => {
                      :by => {
                          :type => 'known',
                          :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                          :accountType => 'atlassian',
                          :email => 'randy.swift@example.com',
                          :publicName => 'Randy Swift',
                          :timeZone => 'UTC',
                          :profilePicture => {
                              :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                              :width => 48,
                              :height => 48,
                              :isDefault => false
                          },
                          :displayName => 'Randy Swift',
                          :isExternalCollaborator => false,
                          :_expandable => {
                              :operations => '',
                              :personalSpace => ''
                          },
                          :_links => {
                              :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                          }
                      },
                      :when => '2022-01-04T14:12:54.208Z',
                      :friendlyWhen => 'yesterday at 2:12 PM',
                      :message => '',
                      :number => 1,
                      :minorEdit => false,
                      :confRev => 'confluence$content$1952055429.2',
                      :contentTypeModified => false,
                      :_expandable => {
                          :collaborators => '',
                          :content => '/rest/api/content/1952055429'
                      },
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952055429/version/1'
                      }
                  },
                  :latest => true,
                  :createdBy => {
                      :type => 'known',
                      :accountId => '5dd6bd2ab5933d0eefaf6fdb',
                      :accountType => 'atlassian',
                      :email => 'workplace-search@elastic.co',
                      :publicName => 'Randy Swift',
                      :timeZone => 'UTC',
                      :profilePicture => {
                          :path => '/wiki/aa-avatar/5dd6bd2ab5933d0eefaf6fdb',
                          :width => 48,
                          :height => 48,
                          :isDefault => false
                      },
                      :displayName => 'Randy Swift',
                      :isExternalCollaborator => false,
                      :_expandable => {
                          :operations => '',
                          :personalSpace => ''
                      },
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/user?accountId=5dd6bd2ab5933d0eefaf6fdb'
                      }
                  },
                  :createdDate => '2022-01-04T14:12:54.208Z',
                  :_expandable => {
                      :previousVersion => '',
                      :contributors => '',
                      :nextVersion => ''
                  },
                  :_links => {
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952055429/history'
                  }
              },
              :ancestors => [],
              :children => {
                  :comment => {
                      :results => [],
                      :start => 0,
                      :limit => 25,
                      :size => 0,
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952055429/child/comment'
                      }
                  },
                  :_expandable => {
                      :attachment => '/rest/api/content/1952055429/child/attachment',
                      :page => '/rest/api/content/1952055429/child/page'
                  },
                  :_links => {
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952055429/child'
                  }
              },
              :container => {
                  :id => 1952055299,
                  :key => '716',
                  :name => '7.16',
                  :type => 'global',
                  :status => 'current',
                  :_expandable => {
                      :settings => '/rest/api/space/716/settings',
                      :metadata => '',
                      :operations => '',
                      :lookAndFeel => '/rest/api/settings/lookandfeel?spaceKey=716',
                      :identifiers => '',
                      :permissions => '',
                      :icon => '',
                      :description => '',
                      :theme => '/rest/api/space/716/theme',
                      :history => '',
                      :homepage => '/rest/api/content/1952055429'
                  },
                  :_links => {
                      :webui => '/spaces/716',
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/space/716'
                  }
              },
              :macroRenderedOutput => {},
              :body => {
                  :export_view => {
                      :value => '\n<div class=\'confluence-information-macro confluence-information-macro-tip\'><span class=\'aui-icon aui-icon-small aui-iconfont-approve confluence-information-macro-icon\'></span><div class=\'confluence-information-macro-body\'>\n    <h3 id=\'id-7.16Home-Welcometoyournewspace\'><strong>Welcome to your new space</strong></h3>\n    <p>Use it to create something wonderful.</p>\n    <p><strong>To start, you might want to:</strong></p>\n    <ul>\n      <li>\n        <p><strong>Customise this overview</strong> using the <strong>edit icon</strong> at the top right of this page.</p>\n      </li>\n      <li>\n        <p><strong>Create a new page</strong> by clicking the <strong>+</strong> in the space sidebar, then go ahead and fill it with plans, ideas, or anything else your heart desires.</p>\n      </li>\n    </ul>\n  </div></div>\n<hr/>\n<p />\n<p />\n<div class=\'confluence-information-macro confluence-information-macro-information\'><span class=\'aui-icon aui-icon-small aui-iconfont-info confluence-information-macro-icon\'></span><div class=\'confluence-information-macro-body\'>\n    <h6 id=\'id-7.16Home-Needinspiration?\'>Need inspiration?</h6>\n    <ul>\n      <li>\n        <p>Get a quick intro into what spaces are, and how to best use them at <a href=\'https://www.atlassian.com/collaboration/confluence-organize-work-in-spaces\' class=\'external-link\' rel=\'nofollow\'>Confluence 101: organize your work in spaces.</a> </p>\n      </li>\n      <li>\n        <p>Check out our guide for ideas on how to <a href=\'https://confluence.atlassian.com/confcloud/set-up-your-space-homepage-827106219.html\' class=\'external-link\' rel=\'nofollow\'>set up your space overview</a>. </p>\n      </li>\n      <li>\n        <p>If starting from a blank space is daunting, try using one of the<a href=\'https://confluence.atlassian.com/display/ConfCloud/Create+a+Space+From+a+Template\' class=\'external-link\' rel=\'nofollow\'> space templates</a> instead.</p>\n      </li>\n    </ul>\n  </div></div>\n<p />',
                      :representation => 'export_view',
                      :_expandable => {
                          :webresource => '',
                          :embeddedContent => '',
                          :mediaToken => '',
                          :content => '/rest/api/content/1952055429'
                      }
                  },
                  :_expandable => {
                      :editor => '',
                      :atlas_doc_format => '',
                      :view => '',
                      :styled_view => '',
                      :dynamic => '',
                      :storage => '',
                      :editor2 => '',
                      :anonymous_export_view => ''
                  }
              },
              :extensions => {
                  :position => 457
              },
              :restrictions => {
                  :read => {
                      :operation => 'read',
                      :restrictions => {
                          :user => {
                              :results => [],
                              :start => 0,
                              :limit => 200,
                              :size => 0
                          },
                          :group => {
                              :results => [],
                              :start => 0,
                              :limit => 200,
                              :size => 0
                          }
                      },
                      :_expandable => {
                          :content => '/rest/api/content/1952055429'
                      },
                      :_links => {
                          :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952055429/restriction/byOperation/read'
                      }
                  },
                  :_expandable => {
                      :update => ''
                  },
                  :_links => {
                      :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952055429/restriction/byOperation'
                  }
              },
              :_expandable => {
                  :childTypes => '',
                  :metadata => '',
                  :operations => '',
                  :schedulePublishDate => '',
                  :version => '',
                  :descendants => '/rest/api/content/1952055429/descendant'
              },
              :_links => {
                  :editui => '/pages/resumedraft.action?draftId=1952055429',
                  :webui => '/spaces/716/overview',
                  :context => '/wiki',
                  :self => 'https://workplace-search.atlassian.net/wiki/rest/api/content/1952055429',
                  :tinyui => '/x/hQBad',
                  :collection => '/rest/api/content',
                  :base => 'https://workplace-search.atlassian.net/wiki'
              }
          }
        end
      end
    end
  end
end

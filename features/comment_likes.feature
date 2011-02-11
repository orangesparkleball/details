@javascript
Feature: Liking a comment on a project wall

  Background: 
    Given a project with users @mislav, @pablo
    And I am logged in as @mislav
    When I go to the project page

  Scenario: I like a comment
    When I fill in the comment box with "Awesome!"
    And I press "Save"
    And I wait for 1 second
    And I follow "Like"
    And I wait for 1 second
    Then I should see "@mislav liked this"

  Scenario: Two of us like a comment
      When I fill in the comment box with "Awesome!"
      And I press "Save"
      And I wait for 1 second
      And I follow "Like"
      And @pablo follows "Like"
      And I wait for 1 second
      Then I should see "@mislav and @pablo liked this"
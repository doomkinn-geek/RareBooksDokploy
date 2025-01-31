using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace RareBooksService.Common.Models.Dto
{
    public class SubscriptionDto
    {
        public int Id { get; set; }
        public int SubscriptionPlanId { get; set; }
        public bool AutoRenew { get; set; }
        public bool IsActive { get; set; }
        public DateTime StartDate { get; set; }
        public DateTime EndDate { get; set; }
        public SubscriptionPlanDto? SubscriptionPlan { get; set; }
    }
}
